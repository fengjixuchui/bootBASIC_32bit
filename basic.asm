        ;
        ; bootBASIC interpreter in 512 bytes (boot sector)
        ;
        ; by Oscar Toledo G.
        ; http://nanochess.org/
        ;
        ; (c) Copyright 2019 Oscar Toledo G.
        ;
        ; Creation date: Jul/19/2019. 10pm to 12am.
        ; Revision date: Jul/20/2019. 10am to 2pm.
        ;                             Added assignment statement. list now
        ;                             works. run/goto now works. Added
        ;                             system and new.
        ; Revision date: Jul/22/2019. Boot image now includes 'system'
        ;                             statement.
        ;

        ; Revision date: Jan/12/2020. Implimentation for macOS(386 32bit) by @taisukef
        ; Revision date: May/18/2020. Implimentation for macOS(x64 64bit) by @taisukef

        ;
        ; USER'S MANUAL:
        ;
        ; Line entry is done with keyboard, finish the line with Enter.
        ; Only 19 characters per line as maximum.
        ;
        ; Backspace can be used, don't be fooled by the fact
        ; that screen isn't deleted (it's all right in the buffer).
        ;
        ; All statements must be in lowercase. -> case insensitive in 64bit version
        ;
        ; Line numbers can be 1 to 999.
        ;
        ; 26 variables are available (a-z)
        ;
        ; Numbers (0-65535) can be entered and display as unsigned.
        ;
        ; To enter new program lines:
        ;   10 print "Hello, world!"
        ;
        ; To erase program lines:
        ;   10
        ;
        ; To test statements directly (interactive syntax):
        ;   print "Hello, world!"
        ;
        ; To erase the current program:
        ;   new
        ;
        ; To run the current program:
        ;   run
        ;
        ; To list the current program:
        ;   list
        ;
        ; To exit to command-line:
        ;   system
        ;
        ; Statements:
        ;   var=expr        Assign expr value to var (a-z)
        ;
        ;   print expr      Print expression value, new line
        ;   print expr;     Print expression value, continue
        ;   print "hello"   Print string, new line
        ;   print "hello";  Print string, continue
        ;
        ;   input var       Input value into variable (a-z)
        ;
        ;   goto expr       Goto to indicated line in program
        ;
        ;   if expr1 goto expr2
        ;               If expr1 is non-zero then go to line,
        ;               else go to following line.
        ;
        ; Examples of if:
        ;
        ;   if c-5 goto 20  If c isn't 5, go to line 20
        ;
        ; Expressions:
        ;
        ;   The operators +, -, / and * are available with
        ;   common precedence rules and signed operation.
        ;
        ;   You can also use parentheses:
        ;
        ;      5+6*(10/2)
        ;
        ;   Variables and numbers can be used in expressions.
        ;
        ; Sample program (counting 1 to 10):
        ;
        ; 10 a=1
        ; 20 print a
        ; 30 a=a+1
        ; 40 if a-11 goto 20
        ;
        ; Sample program (Pascal's triangle, each number is the sum
        ; of the two over it):
        ;
        ; 10 input n
        ; 20 i=1
        ; 30 c=1
        ; 40 j=0
        ; 50 t=n-i
        ; 60 if j-t goto 80
        ; 70 goto 110
        ; 80 print " ";
        ; 90 j=j+1
        ; 100 goto 50
        ; 110 k=1
        ; 120 if k-i-1 goto 140
        ; 130 goto 190
        ; 140 print c;
        ; 150 c=c*(i-k)/k
        ; 160 print " ";
        ; 170 k=k+1
        ; 180 goto 120
        ; 190 print
        ; 200 i=i+1
        ; 210 if i-n-1 goto 30
        ;

        ; cpu 8086 ; original
        cpu x64 ; for 64bit

section .text
global _main

max_line:   equ 10000    ; First unavailable line number (org 1000)
max_length: equ 200      ; Maximum length of line (org 20)
max_size:   equ max_line * max_length ; Max. program size

section .bss
        vars resb (32 * 8)  ; variables 64bit x 32(@,A~Z...)
        line resb 1024 ; line input buffer
        program resb max_size ; Program memory

section .text


_main:
start:
        cld             ; Clear Direction flag
        mov rdi, program  ; Point to program
        mov rax, 0x0d     ; Fill with CR
        mov rcx, max_size ; Max. program size
        rep stosb       ; Initialize

        ; test code
        ; mov rax, 12345678912345678912 ; 64bit output test
        ; call output_number
        ; call new_line
        ; call syscall_exit
        ; mov rax, 10000
        ; call debug_n
        ; call syscall_exit

        ;
        ; Main loop
        ;
main_loop:
        ;mov sp,stack    ; Reinitialize stack pointer
        mov rax, main_loop
        push rax

        xor rax,rax       ; Mark as interactive
        ;mov [running],rax
        mov r10, rax
        mov al, '>'      ; Show prompt
        call input_line ; Accept line
        call input_number       ; Get number
        or rax, rax        ; No number or zero?
        je statement    ; Yes, jump
        call find_line  ; Find the line
        or rax, rax
        jz main_loop_skip ; line number over
        xchg rax, rdi      
;       mov cx, max_length       ; CX loaded with this value in 'find_line'
        rep movsb       ; Copy entered line into program
        ret
main_loop_skip:
        pop rax
        jmp error

        ;
        ; Handle 'if' statement
        ;
if_statement:
        call expr       ; Process expression
        or rax, rax        ; Is it zero?
        je f6           ; Yes, return (ignore if)
statement:
        call spaces     ; Avoid spaces
        cmp byte [rsi], 0x0d  ; Empty line?
        je f6           ; Yes, return
        mov rdi, statements   ; Point to statements list
        mov r11, statements_func
f5:     xor rax, rax
        mov al, [rdi]     ; Read length of the string
        inc rdi          ; Avoid length byte
        and ax, 0x00ff   ; Is it zero?
        je f4           ; Yes, jump
        xchg rax, rcx
        push rsi         ; Save current position
        
        ; Compare statement (rsi, rdi, length:rcx)

        ; case sensitive check (original)
        ; rep cmpsb       
        ; jne statement_not_match          ; Equal? No, jump

        ; case insensitive check
statement_check:
        mov al, [rdi]
        and al, 0xdf
        mov ah, [rsi]
        and ah, 0xdf
        cmp al, ah
        jne statement_not_match
        inc rdi
        inc rsi
        dec rcx
        jnz statement_check
statement_check_end:

        pop rax
        call spaces     ; Avoid spaces
        jmp [r11]   ; Jump to process statement

statement_not_match:
        add rdi, rcx       ; Advance the list pointer
        add r11, 8        ; next func
        pop rsi
        jmp f5          ; Compare another statement

f4:     call get_variable       ; Try variable
        push rax         ; Save address
        lodsb           ; Read a line letter
        cmp al, '='      ; Is it assignment '=' ?
        je assignment   ; Yes, jump to assignment.

        ;
        ; An error happened
        ;
error:
        mov rsi, error_message
        call print_2    ; Show error message
        jmp main_loop   ; Exit to main loop

error_message:
        ; db "@#!",0x0d   ; Guess the words :P
        db "Syntax error", 0x0d

        ;
        ; Handle 'list' statement
        ;
list_statement:
        xor rax, rax       ; Start from line zero
f29:    push rax
        call find_line  ; Find program line
        xchg rax, rsi
        cmp byte [rsi], 0x0d ; Empty line?
        je f30          ; Yes, jump
        pop rax
        push rax
        call output_number ; Show line number
f32:    lodsb           ; Show line contents
        call output
        jne f32         ; Jump if it wasn't 0x0d (CR)
f30:    pop rax
        inc rax          ; Go to next line
        cmp rax, max_line ; Finished?
        jne f29         ; No, continue
f6:
        ret

        ;
        ; Handle 'input' statement
        ;
input_statement:
        call get_variable   ; Get variable address
        push rax             ; Save it
        mov al, '?'          ; Prompt
        call input_line     ; Wait for line
        ;
        ; Second part of the assignment statement
        ;
assignment:
        call expr           ; Process expression
        pop rdi
        mov [rdi], rax      ; save onto variable 64bit
        ret

        ; Handle an expression.
        ; First tier: addition & subtraction.
expr:
        call expr1            ; Call second tier
f20:    cmp byte [rsi], '-'   ; Subtraction operator?
        je f19                ; Yes, jump
        cmp byte [rsi], '+'   ; Addition operator?
        je f20_2
        ret
f20_2:
        push rax
        call expr1_2        ; Call second tier
f15:    pop rcx
        add rax, rcx           ; Addition
        jmp f20             ; Find more operators
f19:
        push rax
        call expr1_2        ; Call second tier
        neg rax              ; Negate it (a - b converted to a + -b)
        jmp f15

        ;
        ; Handle an expression.
        ; Second tier: division & multiplication.
        ;
expr1_2:
        inc rsi              ; Avoid operator
expr1:
        call expr2          ; Call third tier
f21:    cmp byte [rsi], '/'   ; Division operator?
        je f23              ; Yes, jump
        cmp byte [rsi], '*'   ; Multiplication operator?
        jne f6              ; No, return

        push rax
        call expr2_2        ; Call third tier
        pop rcx
        imul rcx             ; Multiplication
        jmp f21             ; Find more operators

f23:
        push rax
        call expr2_2        ; Call third tier
        pop rcx
        cmp rax, 0
        jz expr1_div0
        xchg rax, rcx
        ; cwd                 ; Expand AX to DX:AX
        ;idiv rcx             ; Signed division
        cqo                   ; Expand RAX to RDX:RAX
        idiv rcx              ; singned division RDX:RAX / RCX = RAX (... RDX)
        jmp f21             ; Find more operators
expr1_div0:
        mov rax, 0
        jmp f21

        ;
        ; Handle an expression.
        ; Third tier: parentheses, numbers and vars.
        ;
expr2_2:
        inc rsi              ; Avoid operator
expr2:
        call spaces         ; Jump spaces
        lodsb               ; Read character
        cmp al, '('          ; Open parenthrsis?
        jne f24
        call expr           ; Process inner expr.
        cmp byte [rsi], ')'   ; Closing parenthrsis?
        je spaces_2         ; Yes, avoid spaces
        jmp error           ; No, jump to error

        ;cmp al, '-'          ; minus?
        ;jne f24
        ;inc rsi
        ;lodsb
        ;call f24
        ;neg rax
        ;mov rax, 30
        ;ret
        
f24:    cmp al, 0x40         ; Variable?
        jnc f25              ; Yes, jump
        dec rsi              ; Back one letter...
        call input_number   ; ...to read number
        jmp spaces          ; Avoid spaces
        
f25:    call get_variable_2 ; Get variable address
        xchg rax, rbx
        mov rax, [rbx]         ; Read
        ret                 ; Return

        ;
        ; Get variable address
        ;
get_variable:
        xor rax, rax    ; rax = 0
        lodsb               ; Read source
get_variable_2:
        and rax, 0x1f        ; 0x61-0x7a -> 0x01-0x1a
        shl rax, 3           ; rax <<= 3
        mov r8, vars
        add rax, r8; vars
        ;
        ; Avoid spaces
        ;
spaces:
        cmp byte [rsi], ' '   ; Space found?
        jne spaces_3          ; No, return
        ;
        ; Avoid spaces after current character
        ;
spaces_2:
        inc rsi              ; Advance to next character
        jmp spaces
spaces_3:
        ret

        ;
        ; Output unsigned number (uint_64)
        ; rax = value
output_number:
        or rax, rax
        jns f26
        neg rax
        push rax
        mov al, '-'
        call syscall_putchar
        pop rax
f26:
        mov rcx, 10           ; Divisor = 10
        cqo                   ; expand rax -> rdx:rax
        div rcx              ; Divide rdx:rax / rcx = rax (... rdx)
        or rax, rax            ; Nothing at left?
        push rdx
        je f8               ; No, jump
        call f26            ; Yes, output left side
f8:     pop rax
        add rax, '0'          ; Output remainder as...
        jmp output          ; ...ASCII digit

        ;
        ; Read number in input
        ; rax = result
        ;
input_number:
        xor rbx, rbx           ; BX = 0
f11:    xor rax, rax
        lodsb               ; Read source
        sub al, '0'
        cmp al, 10           ; Digit valid?
        ; cbw ; al -> ax
        xchg rax, rbx
        jnc f12             ; No, jump
        mov rcx, 10           ; Multiply by 10
        mul rcx
        add rbx, rax           ; Add new digit
        jmp f11             ; Continue

f12:    dec rsi              ; SI points to first non-digit
        ret

        ;
        ; Handle 'system' statement
        ;
system_statement:
        mov rdi, 0
        call syscall_exit

        ;
        ; Handle 'goto' statement
        ;
goto_statement:
        call expr           ; Handle expression
        ; and rax, 0xffff
        ;db 0xb9             ; MOV CX to jump over XOR AX,AX
        jmp f10

        ;
        ; Handle 'run' statement
        ; (equivalent to 'goto 0')
        ;
run_statement:
        xor rax, rax
f10:
        call find_line      ; Find line in program
f27:    ;cmp word [running],0 ; Already running?
        cmp r10, 0
        je f31
        ; mov [running],ax    ; Yes, target is new line
        mov r10, rax
        ret
f31:
        push rax
        pop rsi
        add rax, max_length   ; Point to next line
        mov r10, rax ; running = r10
        call statement      ; Process current statement
        mov rax, r10 ; r10 = runnnig
        mov r9, program
        add r9, max_size
        cmp rax, r9 ; Reached the end?
        jne f31             ; No, continue
        ret                 ; Yes, return

        ;
        ; Find line in program
        ; Entry:
        ;   rax = line number
        ; Result:
        ;   rax = pointer to program
        ;   rax = 0 if rax : out of range
find_line:
        or rax, rax
        js find_line_err
        cmp rax, max_line
        jge find_line_err
        mov rcx, max_length
        mul rcx
        mov r9, program
        add rax, r9
        ret
find_line_err:
        xor rax, rax
        ret

        ;
        ; Input line from keyboard
        ; Entry:
        ;   al = prompt character
        ; Result:
        ;   buffer 'line' contains line, finished with CR
        ;   SI points to 'line'.
        ;
input_line:
        call output
        mov rsi, line
        push rsi
        pop rdi          ; Target for writing line
f1:     call input_key  ; Read keyboard
        stosb           ; Save key in buffer
        cmp al,0x08     ; Backspace?
        jne f2          ; No, jump
        dec rdi          ; Get back one character
        dec rdi
f2:     cmp al, 0x0d    ; CR pressed?
        jne f1          ; No, wait another key
        ret             ; Yes, return

        ;
        ; Handle "print" statement
        ;
print_statement:
        lodsb           ; Read source
        cmp al, 0x0d    ; End of line?
        je new_line     ; Yes, generate new line and return
        cmp al, '"'     ; Double quotes?
        jne f7          ; No, jump
print_2:
f9:
        lodsb           ; Read string contents
        cmp al, '"'     ; Double quotes?
        je f18          ; Yes, jump
        call output     ; Output character
        jne f9          ; Jump if not finished with 0x0d (CR)
        ret             ; Return

f7:     dec rsi
        call expr       ; Handle expression
        call output_number      ; Output result
f18:    lodsb           ; Read next character
        cmp al, ';'     ; Is it semicolon?
        jne new_line    ; No, jump to generate new line
        ret             ; Yes, return

        ;
        ; Read a key into al
        ; Also outputs it to screen
        ;
input_key:
        ;mov ah,0x00
        ;int 0x16
        call syscall_getchar

        ;
        ; Screen output of character contained in al
        ; Expands 0x0d (CR) into 0x0a 0x0d (LF CR)
        ;
output:
        cmp al, 0x0d
        jne f17
        ;
        ; Go to next line (generates LF+CR)
        ;
new_line:
        mov al, 0x0a
        call f17
        mov al, 0x0d
f17:
        ;mov ah,0x0e
        ;mov bx,0x0007
        call syscall_putchar ;int 0x10
        cmp al, 0x0d
        ret

debug_n:
        push rax
        push rax
        call new_line
        mov al, '['
        call syscall_putchar
        pop rax
        call output_number
        mov al, ']'
        call syscall_putchar
        call new_line
        pop rax
        ret

        ;
        ; List of statements of bootBASIC
        ; First one byte with length of string
        ; Then string with statement
        ; Then a word with the address of the code
        ;
statements:
        db 3,"new"
        db 4,"list"
        db 3,"run"
        db 5,"print"
        db 5,"input"
        db 2,"if"
        db 4,"goto"
        db 6,"system"
        db 0
statements_func:
        dq start
        dq list_statement
        dq run_statement
        dq print_statement
        dq input_statement
        dq if_statement
        dq goto_statement
        dq system_statement

; syscall for macOS 64bit

section .bss
        putchar_buf resb 1
        getchar_buf resb 1

section .text

syscall_putchar:
        push rcx
        push rdx
        push rbx
        push rax
        push rdi
        push rsi

        mov rsi, putchar_buf            ; buffer
        mov [rsi], al
	mov rax, 0x2000004		; syscall 4: write
	mov rdi, 1	        	; fd = stdout
	mov rdx, 1                      ; size
	syscall

        pop rsi
        pop rdi
        pop rax
        pop rbx
        pop rdx
        pop rcx
        ret

syscall_getchar:
        push rbx
        push rcx
        push rdx
        push rdi
        push rsi

	mov rax, 0x2000003		; syscall 3: read
	mov rdi, 0	        	; fd = stdin
        mov rsi, getchar_buf            ; buffer
	mov rdx, 1                      ; size
	syscall

        mov rsi, getchar_buf
        xor rax, rax
        mov al, [rsi]
        mov ah, 0

        pop rsi
        pop rdi
        pop rdx
        pop rcx
        pop rbx

        ; on Mac 0x0a -> 0x0d
        cmp al, 0x0a
        jne syscall_getchar_skip
        mov al, 0x0d
syscall_getchar_skip:
        ret

syscall_exit: ; retcode: rdi
	mov rax, 0x2000001	; syscall 1: exit
	;mov rdi, 0 		;  retcode
	syscall
        ret
