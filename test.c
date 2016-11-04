#include <stdio.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>

int main(){
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    printf("ts.tv_sec %ld\n", ts.tv_sec);
    printf("ts.tv_nsec %ld\n", ts.tv_nsec);
    struct timeval tv;
    gettimeofday(&tv, NULL);
    printf("tv.tv_sec %ld\n", tv.tv_sec);
    printf("tv.tv_usec %d\n", tv.tv_usec);
    long t_us = (ts.tv_sec * 1000000) + (ts.tv_nsec/1000);
    long t_us1 = (tv.tv_sec * 1000000) + tv.tv_usec;
    printf("t_us %ld\n", t_us);
    printf("t_us1 %ld\n", t_us1);
    return 0;
}