nasm -f macho64 basic.asm
ld -lSystem basic.o -o bootbasic
./bootbasic
echo $?
