#include <stdio.h>
#include <stdlib.h>
#include <mpi.h>
#include <sys/time.h>
#include "MatUtil.h"

int main(int argc, char **argv)
{
	if(argc != 2)
	{
		printf("Usage: test {N}\n");
		exit(-1);
	}
	// Variable initialisation for Sequential and MPI
	struct timeval start, end;
	size_t N = atoi(argv[1]);
	int* mat;
	int* ref;
	// Variable initialisation for MPI
	int myrank;				//process rank
	int p;				//number of processes
	MPI_Comm comm = MPI_COMM_WORLD;
	MPI_Init(&argc, &argv);
	// Get the process rank
  	MPI_Comm_rank(comm, &myrank);
  	// Get the number of the processes
  	MPI_Comm_size(comm, &p);

 
	//sequential computation
	if (myrank == 0) {
		
		mat = (int*)malloc(sizeof(int)*N*N);
		// generate a random matrix.
		GenMatrix(mat, N);
			
		//printf("Init:\n");
		//printMatrix(mat,N,1);
		
		// compute the reference result.
		ref = (int*)malloc(sizeof(int)*N*N);
		memcpy(ref, mat, sizeof(int)*N*N);
		printf("Executing sequentially ...\n");
		gettimeofday(&start,0);
		ST_APSP(ref, N);
		gettimeofday(&end, 0);
		//printf("Ref:\n");
		//printMatrix(ref,N,1);
		
		printf("Sequential execution time = %ld usecs\n",
			(end.tv_sec-start.tv_sec)*1000000+(end.tv_usec-start.tv_usec));
	}

	// parallel computation
	// Broadcast N value
	MPI_Bcast(&N, 1, MPI_INT, 0, comm);

	int* localMatrix = (int*)malloc(sizeof(int)*N*N/p);
	if (myrank == 0) {
		printf("Executing in parallel ...\n");
		gettimeofday(&start,0);
	}
	// Scatter data to p processors
	MPI_Scatter(mat, N*N/p, MPI_INT, localMatrix, N*N/p, MPI_INT, 0, comm);

	//printf("Local Matrix: %d\n", myrank);
	//printMatrix(localMatrix,N,p);

	// Compute
	MT_APSP(localMatrix, N, comm, myrank, p);
	//printf("Result Local Matrix: %d\n", myrank);
	//printMatrix(localMatrix,N,p);
	
	// Gather the result
	MPI_Gather(localMatrix,	N*N/p, MPI_INT, mat, N*N/p, MPI_INT, 0, comm);
	if (myrank == 0)
		gettimeofday(&end,0);
	MPI_Finalize();
	
	// Print out the resulting matrix
	if (myrank == 0) {
		//printf("The solution is:\n");
		//printMatrix(mat,N,1);

		// compare your result with reference result
		if(CmpArray(mat, ref, N*N))
			printf("Your result is correct.\n");
		else
			printf("Your result is wrong.\n");

		printf("Parallel execution time = %ld usecs\n",
			(end.tv_sec-start.tv_sec)*1000000+(end.tv_usec-start.tv_usec));
	}
}
