#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include "MatUtil.h"
#include <omp.h>

int main(int argc, char **argv)
{
	if(argc < 2)
	{
		printf("Usage: test {N}\n");
		exit(-1);
	}
	// Variable initialisation for Sequential and OpenMP
	struct timeval start, end;
	size_t N = atoi(argv[1]);
	int* mat;
	int* ref;
	// Variable initialisation for OpenMP
	int thread_id, n;
 	
	//sequential computation
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
	
	//parallel computation using OpenMP
	printf("Executing in parallel ...\n");
	gettimeofday(&start,0);
	OMP_APSP(mat, N);
	gettimeofday(&end, 0);
	//printf("Result:\n");
	//printMatrix(mat,N,1);

	printf("OpenMP execution time = %ld usecs\n",
		(end.tv_sec-start.tv_sec)*1000000+(end.tv_usec-start.tv_usec));
		
	
	if(CmpArray(mat, ref, N*N))	printf("Your result is correct\n");
	else 				printf("Your result is wrong\n");
}
