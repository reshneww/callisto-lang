section .data
    filename    db "output.elf", 0
    O_WRONLY    equ 1
    O_CREAT     equ 64
    O_TRUNC     equ 512
    MODE        equ 0755o

section .bss
    fd          resd 1

section .text
global write_elf

write_elf:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov  r12, rsi
    mov  r13, rdx

    ; Dosyayi ac
    mov  rax, 2
    lea  rdi, [rel filename]
    mov  rsi, O_WRONLY | O_CREAT | O_TRUNC
    mov  rdx, MODE
    syscall
    test rax, rax
    js   .error
    mov  [rel fd], eax
    mov  r14d, eax

    ; ELF header yaz (64 byte)
    sub  rsp, 64
    mov  rdi, rsp
    call .build_elf_header

    mov  rax, 1
    mov  rdi, r14
    mov  rsi, rsp
    mov  rdx, 64
    syscall
    add  rsp, 64
    cmp  rax, 64
    jne  .error

    ; Program header yaz (56 byte)
    sub  rsp, 56
    mov  rdi, rsp
    call .build_prog_header

    mov  rax, 1
    mov  rdi, r14
    mov  rsi, rsp
    mov  rdx, 56
    syscall
    add  rsp, 56
    cmp  rax, 56
    jne  .error

    ; Kodu yaz
    mov  rax, 1
    mov  rdi, r14
    mov  rsi, r12
    mov  rdx, r13
    syscall

.close:
    mov  rax, 3
    mov  rdi, r14
    syscall

.done:
    xor  rax, rax
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    pop  rbp
    ret

.error:
    movsx rax, eax
    jmp  .close

; ELF Header — 64 byte
.build_elf_header:
    ; Tamponu sifirla
    push rdi
    xor  eax, eax
    mov  ecx, 8
    rep  stosq
    pop  rdi

    mov  dword [rdi],      0x464c457f  ; Magic: .ELF
    mov  byte  [rdi+4],    2           ; 64-bit
    mov  byte  [rdi+5],    1           ; little-endian
    mov  byte  [rdi+6],    1           ; ELF version
    mov  byte  [rdi+7],    0           ; Linux ABI
    ; +8 ile +15 arasi padding (sifir)
    mov  word  [rdi+16],   2           ; ET_EXEC
    mov  word  [rdi+18],   62          ; x86-64
    mov  dword [rdi+20],   1           ; ELF version
    mov  qword [rdi+24],   0x400078    ; entry point
    mov  qword [rdi+32],   64          ; program header offset
    mov  qword [rdi+40],   0           ; section header offset (yok)
    mov  dword [rdi+48],   0           ; flags
    mov  word  [rdi+52],   64          ; ELF header boyutu
    mov  word  [rdi+54],   56          ; program header boyutu
    mov  word  [rdi+56],   1           ; program header sayisi
    mov  word  [rdi+58],   64          ; section header boyutu
    mov  word  [rdi+60],   0           ; section header sayisi
    mov  word  [rdi+62],   0           ; string table index
    ret

; Program Header — 56 byte
.build_prog_header:
    ; Tamponu sifirla
    push rdi
    xor  eax, eax
    mov  ecx, 7
    rep  stosq
    pop  rdi

    mov  dword [rdi+0],    1           ; PT_LOAD
    mov  dword [rdi+4],    5           ; PF_R | PF_X (oku + calistir)
    mov  qword [rdi+8],    0           ; dosyadaki offset
    mov  qword [rdi+16],   0x400000    ; sanal adres
    mov  qword [rdi+24],   0x400000    

    ; dosya boyutu = header (120) + kod
    mov  rax, r13
    add  rax, 120
    mov  qword [rdi+32],   rax         ; dosyadaki boyut
    mov  qword [rdi+40],   rax         ; bellekteki boyut

    mov  qword [rdi+48],   0x1000      ; hizalama (4096) — duzeltildi
    ret