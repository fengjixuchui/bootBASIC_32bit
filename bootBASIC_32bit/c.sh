nasm -f macho32 basic.asm
ld -lSystem basic.o -o bootbasic
./bootbasic
