// Portable equivalent of the TA atomic gated.txt counter (10,11,13 gates).
#include <fstream>
#include <iostream>
#include <stdexcept>
#ifdef _WIN32
#include <windows.h>
#else
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
#endif
#ifndef GATE_WEIGHT
#error Compile with -DGATE_WEIGHT=10, 11 or 13
#endif

int main() {
#ifdef _WIN32
    HANDLE lock = CreateMutexA(nullptr, FALSE, "CAD_CA2_GATED_COUNTER");
    if (!lock) return 2;
    DWORD status = WaitForSingleObject(lock, INFINITE);
    if (status != WAIT_OBJECT_0 && status != WAIT_ABANDONED) return 3;
#else
    int lock = open("gated.lock", O_CREAT | O_RDWR, 0600);
    if (lock < 0 || flock(lock, LOCK_EX) != 0) return 2;
#endif
    int result = 0;
    try {
        long long gates;
        std::ifstream input("gated.txt");
        if (!(input >> gates) || gates < 0) throw std::runtime_error("gated.txt must contain a nonnegative integer");
        input.close();
        std::ofstream output("gated.txt", std::ios::trunc);
        output << gates + GATE_WEIGHT << '\n';
        output.close();
        if (!output) throw std::runtime_error("Cannot write gated.txt");
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        result = 1;
    }
#ifdef _WIN32
    ReleaseMutex(lock);
    CloseHandle(lock);
#else
    flock(lock, LOCK_UN);
    close(lock);
#endif
    return result;
}
