#include <stdio.h>
#include <mpi.h>
#include <sys/time.h>
#include <string.h>

#define MAXCOUNT 100000

typedef unsigned long long int pptimer_t;

int main(int argc, char *argv[]) {
	int namelen, proc_rank, recv_rank, proc_size;

	// the program will be repeated for 50 times for better accuracy
	int N = 1000, i, count;

	// declare 2 message nodes
	char *message1= (char *)malloc(MAXCOUNT*sizeof(char));
	char *message2= (char *)malloc(MAXCOUNT*sizeof(char));

	pptimer_t time_diff;

	struct timeval tv1, tv2;
	struct timezone tz1, tz2;

	char proc_name[MPI_MAX_PROCESSOR_NAME];
	char recv_name[MPI_MAX_PROCESSOR_NAME];
	MPI_Status status;
	
	MPI_Init(&argc, &argv);						// Initialize MPI environment
	MPI_Comm_rank(MPI_COMM_WORLD, &proc_rank);	// Get the address of rank
	MPI_Comm_size(MPI_COMM_WORLD, &proc_size); 	// Get the number of the processes
	// assign values to 2 strings
	for(i = 0; i< MAXCOUNT; i++)
		message1[i] = 't';
	strcpy(message2, message1);

	// this program only support 2 processes
	if (proc_size != 2){
		fprintf(stderr, "World size must be two for %s \n", argv[0]);
		MPI_Abort(MPI_COMM_WORLD, 1);
	}

	// for process 0
	if (proc_rank == 0) {
		//start timer
		gettimeofday(&tv1, &tz1);

		// repeat N times for better accuracy
		for (i = 0; i < N; i++){   
			MPI_Send(message1, MAXCOUNT, MPI_CHAR, 1, 3, MPI_COMM_WORLD);
			MPI_Recv(message2, MAXCOUNT, MPI_CHAR, 1, 5, MPI_COMM_WORLD, &status);
		}

		// stop the timer	
		gettimeofday(&tv2, &tz2);
		time_diff = ((tv2.tv_sec - tv1.tv_sec)*1000000 + tv2.tv_usec - tv1.tv_usec)/2;
		printf("Elapsed time = %ld usecs\n",time_diff/N);
	} 

	// for process 1
	else if(proc_rank == 1) {
		for (i = 0; i < N; i++) {	
			MPI_Recv(message1, MAXCOUNT, MPI_CHAR, 0, 3, MPI_COMM_WORLD, &status); 
			MPI_Send(message2, MAXCOUNT, MPI_CHAR, 0, 5, MPI_COMM_WORLD);
		}   
	}

	free(message1);
	free(message2);
	MPI_Finalize();
	return 0;
}
