public class Q2 {
	static int[] array = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20};
	static int comparison = 0;		//complexity identifier
	public static void main(String[] args) {
		int middleNumber = modifiedQuickSort(array, 0, array.length);
		System.out.println("Middle Number: "+middleNumber);
		System.out.println("Number of comparison: " + comparison);
	}
	
	public static int modifiedQuickSort(int[] ar, int begin, int end) {
		int middle = (begin + end)/2;		//index of middle element (random)
		//System.out.print("begin: " + begin + ", end: " + end + "\n");						..debug
		//print();																			..debug
		swap(ar,begin,middle);
		//System.out.print("middle element: " + ar[begin] + "\n");							..debug
		int pointer = begin;	//pointer for swapping the element in the end of quicksort
		int i = begin+1;		//for looping
		
		while(i < end) //sorting
		{
			if (pointer > array.length/2) { //just get the max element from the lower part of the half sorted array{
				swap(ar,begin,pointer);
				//print();
				return findLargest();
			}
			
			//System.out.print("State: " + i + ", Pointer: " + pointer +"\n");				..debug
			//comparison
			comparison++;
			if (ar[i] <= ar[begin])
				swap(ar,++pointer,i++);
			else
				i++;
		}
		swap(ar,begin,pointer);	// begin ------ pointer ------ end
		//search the upper part
		return modifiedQuickSort(ar, pointer+1, end);
	}
	
	public static void swap(int ar[], int i, int j) {
		int temp = ar[j];
		ar[j] = ar[i];
		ar[i] = temp;
	}
	
	public static void print() {
		for (int a:array) System.out.print(a+", ");
		System.out.println();
	}
	
	public static int findLargest() {
		int largest = array[0];
		for (int i = 1; i <= array.length/2; i++) {
			//compare again
			comparison++;
			largest = (array[i] > largest) ? array[i] : largest;
		}
		return largest;
	}
}