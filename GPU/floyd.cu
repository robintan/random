// includes, system
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <sys/time.h>

// includes CUDA
#include <cuda_runtime.h>

#define TPB 32
////////////////////////////////////////////////////////////////////////////////
// declaration, forward

void runFloyd(int *mat, const size_t N);
void GenMatrix(int *mat, const size_t N);
void ST_APSP(int *mat, const size_t N);
void printMatrix(int *mat, const size_t N);
bool CmpArray(const int *l, const int *r, const size_t eleNum);

/*
	Generate Matrix
*/
void GenMatrix(int *mat, const size_t N)
{
	for(int i = 0; i < N; i ++)
		for(int j = 0; j < N; j++)
			mat[i*N+j] = (i==j)?0:rand()%32 - 1;
}

/*
	Sequential (Single Thread) APSP on CPU.
*/
void ST_APSP(int *mat, const size_t N)
{
	for(int k = 0; k < N; k ++)
		for(int i = 0; i < N; i ++)
			for(int j = 0; j < N; j ++)
			{
				int i0 = i*N + j;
				int i1 = i*N + k;
				int i2 = k*N + j;
				if(mat[i1] != -1 && mat[i2] != -1)
					mat[i0] = min(mat[i0], mat[i1] + mat[i2]);
			}
}

/*
	Compare two array
*/
bool CmpArray(const int *l, const int *r, const size_t eleNum)
{
	for(int i = 0; i < eleNum; i ++)
		if(l[i] != r[i])
		{
			printf("ERROR: l[%d] = %d, r[%d] = %d\n", i, l[i], i, r[i]);
			return false;
		}
	return true;
}

void printMatrix (int*mat, const size_t N) {
	for (int i = 0; i< N; i++) {
		for(int j= 0; j< N; j++) {
 			int value = mat[i*N +j];
				printf("%d, ",value);
		}
		printf("\n");
	}
}

__global__ void
transpose(int* mat, int* result, const size_t N) {
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	int j = blockIdx.y * blockDim.y + threadIdx.y;
	if (i < N && j < N)
		result[j*N + i] = mat[i*N + j];
}

/*
	GPU kernel function
*/
__global__ void
floydKernel(int k, int *result_d, const size_t N)
{
	int x = blockIdx.x * blockDim.x + threadIdx.x;
	int y = blockIdx.y * blockDim.y + threadIdx.y;
	
	if(x < N && y < N){
		int xk = x*N+k;
		int ky = k*N+y;
		int xy = x*N+y;
		if((result_d[xk] != -1) && (result_d[ky]!=-1))
			result_d[xy] = min(result_d[xy],result_d[xk] + result_d[ky]);
	}
	__syncthreads();
}

/*
	Call kernel function from Host
*/
void runFloyd(int *result, const size_t N)
{
	int size = N * N * sizeof(int);
	int *result_d;
	
	cudaMalloc((int **) &result_d, size);
	cudaMemcpy(result_d, result, size, cudaMemcpyHostToDevice);

	dim3 Grid(N/TPB,N/TPB,1);
	dim3 Block(TPB,TPB,1);
	
	if (N%TPB!=0) {	//ceiling function
		Grid.x++; Grid.y++;
	}
	
	for(int k = 0; k < N; k++){
		floydKernel<<<Grid, Block>>>(k, result_d,N);
	}
	cudaMemcpy(result, result_d, size, cudaMemcpyDeviceToHost);
	cudaFree(result_d);
}

__global__ void
coalesceKernel (int k, int *mat, int *transposed_mat, const size_t N) {
	int x = blockIdx.x * blockDim.x + threadIdx.x;
	int y = blockIdx.y * blockDim.y + threadIdx.y;
	
	if (x < N && y < N) 
		if (transposed_mat[k*N + x] != -1 && mat[k*N + y] != -1) {	//transposed_mat[k,x] = mat[x,k] --> coalesced
			mat[x*N + y] = min(transposed_mat[k*N + x] + mat[k*N + y],mat[x*N+y]);
			transposed_mat[y*N + x] = mat[x*N + y];	//update both to avoid overhead
		}
	__syncthreads();
}

void runFloyd_coalescing(int *result, const size_t N)
{
	int size = N * N * sizeof(int);
	int *result_d;
	cudaMalloc((int **) &result_d, size);
	cudaMemcpy(result_d, result, size, cudaMemcpyHostToDevice);
	
	int *transposed_mat_d;
	cudaMalloc((int **) &transposed_mat_d, size);
	
	dim3 Grid(N/TPB,N/TPB,1);
	dim3 Block(TPB,TPB,1);
	if (N%TPB!=0) {	//ceiling function
		Grid.x++; Grid.y++;
	}
	transpose<<<Grid, Block>>>(result_d, transposed_mat_d, N);
	
	for(int k = 0; k < N; ++k) {
		coalesceKernel<<<Grid, Block>>>(k, result_d, transposed_mat_d, N);
	}
	cudaMemcpy(result,result_d,size,cudaMemcpyDeviceToHost);
	cudaFree(transposed_mat_d);
	cudaFree(result_d);
}

__global__ void
sharedKernel (int k, int *mat, const size_t N) {
	extern __shared__ int smem[];

	int x = blockIdx.x * blockDim.x + threadIdx.x;
	int y = blockIdx.y * blockDim.y + threadIdx.y;

	if (x < N && y < N) {
		if (threadIdx.x == 0) {		//to avoid reading from memory all the time, 
									//the number of times it reads from memory is just 2*TPB times.
			smem[TPB+threadIdx.y] = mat[k*N + y];	//KJ
		} if (threadIdx.y == 0) {
			smem[threadIdx.x] = mat[x*N + k];		//IK
		}
		__syncthreads();			//make sure the arrays are filled
		if (smem[threadIdx.x] != -1 && smem[TPB+threadIdx.y] != -1)		//number of times the shared memory is accessed = TPB*TPB
			mat[x*N+y] = min(smem[threadIdx.x] + smem[TPB+threadIdx.y], mat[x*N+y]);
	}
	__syncthreads();
}

void runFloyd_shared(int *result, const size_t N)
{
	int size = N * N * sizeof(int);
	int *result_d;
	cudaMalloc((int **) &result_d, size);
	cudaMemcpy(result_d, result, size, cudaMemcpyHostToDevice);
	
	dim3 Grid(N/TPB,N/TPB,1);
	dim3 Block(TPB,TPB,1);
	if (N%TPB!=0) {	//ceiling function
		Grid.x++; Grid.y++;
	}

	for(int k = 0; k < N; ++k) {
		sharedKernel<<<Grid, Block, (2*TPB)*sizeof(int)>>>(k, result_d, N);
	}
	cudaMemcpy(result,result_d,size,cudaMemcpyDeviceToHost);
	cudaFree(result_d);
}

__global__ void
sharedCoalescedKernel (int k, int *mat, int *transposed_mat, const size_t N) {
	extern __shared__ int smem[];

	int x = blockIdx.x * blockDim.x + threadIdx.x;
	int y = blockIdx.y * blockDim.y + threadIdx.y;

	if (x < N && y < N) {
		if (threadIdx.x == 0) {		//to avoid reading from memory all the time, 
									//the number of times it reads from memory is just 2*TPB times.
			smem[TPB+threadIdx.y] = mat[k*N + y];			//KJ
		} if (threadIdx.y == 0) {
			smem[threadIdx.x] = transposed_mat[k*N + x];	//KI ==> equivalent to IK of mat
		}
		__syncthreads();			//make sure the arrays are filled
		if (smem[threadIdx.x] != -1 && smem[TPB+threadIdx.y] != -1) {
			mat[x*N+y] = min(smem[threadIdx.x] + smem[TPB+threadIdx.y], mat[x*N+y]);	//number of times being accessed TPB*TPB
			transposed_mat[y*N+x] = mat[x*N+y];
		}
	}
	__syncthreads();
}

void runFloyd_sharedCoalesced(int *result, const size_t N)
{
	int size = N * N * sizeof(int);
	int *result_d;
	cudaMalloc((int **) &result_d, size);
	cudaMemcpy(result_d, result, size, cudaMemcpyHostToDevice);
	
	int *transposed_mat_d;
	cudaMalloc((int **) &transposed_mat_d, size);
	
	dim3 Grid(N/TPB,N/TPB,1);
	dim3 Block(TPB,TPB,1);
	if (N%TPB!=0) {	//ceiling function
		Grid.x++; Grid.y++;
	}

	transpose<<<Grid, Block>>>(result_d, transposed_mat_d, N);
	
	for(int k = 0; k < N; ++k) {
		sharedCoalescedKernel<<<Grid, Block, (2*TPB)*sizeof(int)>>>(k, result_d, transposed_mat_d, N);
	}
	cudaMemcpy(result,result_d,size,cudaMemcpyDeviceToHost);
	cudaFree(transposed_mat_d);
	cudaFree(result_d);
}


////////////////////////////////////////////////////////////////////////////////
// Program main
////////////////////////////////////////////////////////////////////////////////
int
main(int argc, char **argv)
{
	cudaEvent_t begin, stop;
	cudaEventCreate(&begin);
	cudaEventCreate(&stop);
	float dt_ms;
	long int usec;	
	struct timeval start, end;
	
	if (argc < 1) {
		printf("Usage: N [TPB]\n");
		return 0;
	}
	
	// generate a random matrix.
	size_t N = atoi(argv[1]);
	int *mat = (int*)malloc(sizeof(int) * N * N);
	GenMatrix(mat, N);
	
 	// compute the reference result.
	int *ref = (int*)malloc(sizeof(int) * N * N);
	memcpy(ref, mat, sizeof(int) * N * N);
	
	// PERFORM COMPUTATION ON HOST CPU
	gettimeofday(&start,0);
	ST_APSP(ref, N);
	gettimeofday(&end,0);
        printf("Sequential execution time = %ld usecs \n\n", (end.tv_sec - start.tv_sec) * 1000000 + (end.tv_usec - start.tv_usec));
    
	// PERFORM COMPUTATION ON GPU
	int *result = (int*)malloc(sizeof(int) * N * N);
	memcpy(result, mat, sizeof(int)*N*N);
	cudaEventRecord(begin,0);
  	runFloyd(result, N);
	cudaEventRecord(stop,0);

	cudaEventSynchronize(begin);
	cudaEventSynchronize(stop);
	
	cudaEventElapsedTime(&dt_ms, begin, stop);
	usec = dt_ms *1000;
	printf("CUDA Normal execution time = % ld usecs \n",usec);

	// compare your result with reference result
	if(CmpArray(result, ref, N * N))	printf("Your result is correct.\n\n");
	else								printf("Your result is wrong.\n\n");
	

	// PERFORM COMPUTATION ON GPU WITH MEMORY COALESCING METHOD
	int *coalesced_result = (int*)malloc(sizeof(int) * N * N);
	memcpy(coalesced_result, mat, sizeof(int)*N*N);
	cudaEventRecord(begin,0);
	runFloyd_coalescing(coalesced_result, N);
	cudaEventRecord(stop,0);
	cudaEventSynchronize(begin);
	cudaEventSynchronize(stop);
	
	cudaEventElapsedTime(&dt_ms, begin, stop);
	usec = dt_ms *1000;
	printf("CUDA Coalescing execution time = % ld usecs \n",usec);

	if(CmpArray(coalesced_result, ref, N * N))	printf("Your result is correct.\n\n");
	else								printf("Your result is wrong.\n\n");
	
	// PERFORM COMPUTATION ON GPU WITH MEMORY TILING SHARED MEMORY METHOD
	int *shared_result = (int*)malloc(sizeof(int) * N * N);
	memcpy(shared_result, mat, sizeof(int)*N*N);
	cudaEventRecord(begin,0);
	runFloyd_shared(shared_result, N);
	cudaEventRecord(stop,0);
	cudaEventSynchronize(begin);
	cudaEventSynchronize(stop);
	
	cudaEventElapsedTime(&dt_ms, begin, stop);
	usec = dt_ms *1000;
	printf("CUDA SM execution time = % ld usecs \n",usec);

	if(CmpArray(shared_result, ref, N * N))	printf("Your result is correct.\n\n");
	else								printf("Your result is wrong.\n\n");
	
	// PERFORM COMPUTATION ON GPU WITH MEMORY TILING SHARED MEMORY AND COALESCING METHOD METHOD
	int *shared_coalesced_result = (int*)malloc(sizeof(int) * N * N);
	memcpy(shared_coalesced_result, mat, sizeof(int)*N*N);
	cudaEventRecord(begin,0);
	runFloyd_sharedCoalesced(shared_coalesced_result, N);
	cudaEventRecord(stop,0);

	cudaEventSynchronize(begin);
	cudaEventSynchronize(stop);
	
	cudaEventElapsedTime(&dt_ms, begin, stop);
	usec = dt_ms *1000;
	printf("CUDA SM+Coalesceing execution time = % ld usecs \n",usec);
	
	if(CmpArray(shared_coalesced_result, ref, N * N))	printf("Your result is correct.\n\n");
	else												printf("Your result is wrong.\n\n");

	cudaEventDestroy(begin);
	cudaEventDestroy(stop);
}




