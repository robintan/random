#include "MatUtil.h"
#include <mpi.h>

inline int min(int a, int b) {
	return (a != -1 && a < b) ? a : b;
}

void GenMatrix(int *mat, const size_t N)
{
	for(int i = 0; i < N; i ++)
		for(int j = 0; j < N; j ++)
			mat[i*N+j] = (i==j)?0:rand()%32 - 1;
}

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


/*
	Sequential (Single Thread) APSP on CPU.
*/
void ST_APSP(int *mat, const size_t N)
{
	for(int k = 0; k < N; k ++)
		for(int i = 0; i < N; i ++)
			for(int j = 0; j < N; j ++) {
				int i0 = i*N + j;	//i0 = mat[i][j]
				int i1 = i*N + k;	//i1 = mat[i][k]
				int i2 = k*N + j;	//i2 = mat[k][j]
				if(mat[i1] != -1 && mat[i2] != -1)
					mat[i0] = min(mat[i0], mat[i1] + mat[i2]);
			}
}
/*
  Multiple thread (Parallel) APSP on CPU
*/
void MT_APSP(int *part, const size_t N, MPI_Comm comm, int myrank, int p) {
	int s = N/p;
	int root, offset;
	int *temp = (int*)malloc(sizeof(int)*N);

	for (int k = 0; k < N; k++) {
		root = k/s;
		if (myrank == root) {
			offset = k - myrank*s;
			for (int j = 0; j < N; j++) 
				temp[j] = part[offset*N + j];
		} 
		MPI_Bcast(temp, N, MPI_INT, root, comm);
		for(int i = 0; i < s; i ++)
			for(int j = 0; j < N; j ++) {
				int i0 = i*N + j;
				int i1 = i*N + k;
				if (part[i1] != -1 && temp[j] != -1)
					part[i0] = min(part[i0], part[i1] + temp[j]);
			}
	}
}

void printMatrix (int *mat, const size_t N, int p) {
	for (int i = 0; i < N/p; i++) {
		for(int j = 0; j < N ; j++) {
			int value = mat[i*N + j];
			printf("%d\t", value);
		}
		printf("\n");
	}
}


