#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>

int main() {
    int *ptr = mmap ( 0, 2048, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_SHARED | MAP_ANONYMOUS, 0, 0 );
    perror("mmap");
    ptr[0] = 1;
    ptr[1] = 2;
    exit(0);
}