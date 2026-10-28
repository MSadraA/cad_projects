#include <iostream>
#include <fstream>
#include <string>
#include <sys/file.h>
#include <unistd.h>
#include <fcntl.h>

int main() {
    // ایجاد یا باز کردن یک فایل کمکی برای قفل‌گذاری (معادل Mutex)
    int lock_fd = open("gated.lock", O_RDWR | O_CREAT, 0666);
    if (lock_fd == -1) return 1;

    // منتظر ماندن برای دریافت قفل انحصاری
    flock(lock_fd, LOCK_EX);

    std::ifstream f("gated.txt");
    if (!f.is_open()) {
        std::cerr << "Error opening the file!";
        flock(lock_fd, LOCK_UN);
        close(lock_fd);
        return 1;
    }

    std::string s;
    getline(f, s);
    int number = std::stoi(s);
    f.close();

    number += 10;

    std::ofstream MyFile("gated.txt", std::ios::trunc);
    MyFile << number;
    MyFile.close();

    // آزادسازی قفل
    flock(lock_fd, LOCK_UN);
    close(lock_fd);

    return 0;
}