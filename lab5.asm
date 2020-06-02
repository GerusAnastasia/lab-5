.model small
.stack 100h
.data
    max_path_size           equ 124
    file_path               db max_path_size dup (0)
    old_str                 db max_path_size dup (0)
    new_str                 db max_path_size dup (0)
    buf                     db ?
    PSP                     dw ?
    old_size                db ?
    new_size                db ?
    EOF                     db ?
    message_old_str         db "old string: ", '$'
    message_new_str         db "new string: ", '$'
    message_file_path       db "filename: ", '$'
    wrong_args              db "Wrong args", 0Dh, 0Ah
                            db "Correct format:", 0Dh, 0Ah
                            db "filepath arg1 arg2", 0Dh, 0Ah, '$'
    unidentifyed_error      db "unidentified error", 0Dh, 0Ah, '$'
    function_number_invalid db "function number invalid", 0Dh, 0Ah, '$'
    file_not_found          db "file not found", 0Dh, 0Ah, '$'
    path_not_found          db "path not found", 0Dh, 0Ah, '$'
    too_many_open_files     db "too many open files (no handles available)", 0Dh, 0Ah, '$'
    access_denied           db "access denied", 0Dh, 0Ah, '$'
    invalid_handle          db "invalid handle", 0Dh, 0Ah, '$'
    access_code_invalid     db "access code invalid", 0Dh, 0Ah, '$'
    invalid_password        db "invalid password", 0Dh, 0Ah, '$'
.code
    jmp start

printlnd macro
    push ds
    push si
    push cx
    push ax

    mov ds, bx

    parse_command_line_loop:
        lodsb
        mov dl, al
        mov ah, 2
        int 21h
        loop parse_command_line_loop
    mov dl, 0Dh
    mov ah, 2
    int 21h
    mov dl, 0Ah
    mov ah, 2
    int 21h

    pop ax
    pop cx
    pop si
    pop ds
endm

check_size macro str
    push cx
    mov di, offset str
    call strlen
    cmp cx, 0
    je parse_command_line_error
    pop cx
endm

parse_command_line proc;
    push si
    push di
    push ax
    push cx

    mov ah, 62h
    int 21h
    mov PSP, bx

    push ds

    mov ds, bx
    xor ah, ah
    mov al, byte ptr ds:[80h]              ;num of symbols of command line
    pop ds
    cmp al, 0
    je parse_command_line_error

    xor ch, ch
    mov cl, al
    mov si, 81h
    
    mov di, offset file_path    ;di - start of com line in prog, si - start of com line
    call get_word
    jc parse_command_line_error

    check_size file_path
    
    mov di, offset old_str
    call get_word
    jc parse_command_line_error

    check_size old_str
    
    mov di, offset new_str
    call get_word
    jc parse_command_line_error

    check_size new_str

    call check_if_ended
    jnc parse_command_line_error

    parse_command_line_fine:
    clc
    jmp parse_command_line_end

    parse_command_line_error:
    stc
    jmp parse_command_line_end

    parse_command_line_end:
    pop cx
    pop ax
    pop di
    pop si
    ret
endp

check_if_ended proc; si - source, cx - size
    push si
    push di
    push ax
    push cx

    mov di, si
    mov al, ' '
    repe scasb
    cmp cx, 0
    je check_if_ended_error

    check_if_ended_fine:
    clc
    jmp check_if_ended_end

    check_if_ended_error:
    stc
    jmp check_if_ended_end

    check_if_ended_end:
    pop cx
    pop ax
    pop di
    pop si
    ret
endp

get_word proc; si - source, di - dest, cx - size; output: si is modified, cx is modified
    push bx
    push ax
    push di
    push ds

    mov ax, PSP
    mov ds, ax

    mov bx, di
    mov di, si
    cmp byte ptr [di], ' '      ;if not first word
    jne get_word_no_spaces
    mov al, ' '
    repe scasb
    get_word_no_spaces:
    mov si, di
    mov di, bx
    cmp cx, 0
    je get_word_error

    cmp byte ptr [si], '"'
    jne get_word_space_loop
    inc si
    dec cx

    get_word_loop:
        lodsb
        cmp al, '"'
        je get_word_space
        stosb
        loop get_word_loop
    jmp get_word_error

    get_word_space_loop:
        lodsb
        cmp al, ' '
        je get_word_space
        stosb
        loop get_word_space_loop

    jmp get_word_fine

    get_word_space:
    dec cx
    jmp get_word_fine

    get_word_fine:
    clc
    jmp get_word_end

    get_word_error:
    stc
    jmp get_word_end

    get_word_end:
    pop ds
    pop di
    pop ax
    pop bx
    ret
endp

replace_strings proc; bx - file descr
    push di
    push cx

    mov di, offset old_str
    call strlen
    mov old_size, cl

    mov di, offset new_str
    call strlen
    mov new_size, cl

    xor cx, cx
    
    mov EOF, 0

    mov di, offset old_str
    replace_strings_loop:
        call check_if_str
        jnc replace_strings_no
        call replace_string
        jmp replace_strings_loop
        replace_strings_no:
        cmp EOF, 1
        je replace_strings_end
        call point_to_next
        jmp replace_strings_loop

    replace_strings_end:
    pop cx
    pop di
    ret
endp

replace_string proc; bx - file descr
    push ax
    push cx
    push dx
    push si
    
    mov dx, bx
    mov al, old_size
    mov ah, new_size
    call min
    xor ch, ch
    mov cl, bl              ; min size
    mov bx, dx

    mov si, offset new_str
    mov dx, offset buf
    replace_string_lin_loop:
        lodsb
        push cx
        mov ah, 40h
        mov cx, 1
        mov buf, al
        int 21h
        pop cx
        loop replace_string_lin_loop

    mov al, old_size
    cmp al, new_size
    je replace_string_end
    ja replace_string_truncate

    replace_string_extend:
    call insert_in_file
    jmp replace_string_end

    replace_string_truncate:
    push bx
    mov bh, old_size
    mov bl, new_size
    sub bh, bl
    xor ch, ch
    mov cl, bh
    pop bx
    call delete_from_file


    replace_string_end:
    pop si
    pop dx
    pop cx
    pop ax
    ret
endp

pos_high    dw ?
pos_low     dw ?

insert_in_file proc; bx - file descr, si - str
    push ax
    push dx
    push cx
    push di
    
    mov di, si
    call strlen

    mov di, cx; di - size
    dec di

    mov ah, 42h; save original pos
    mov al, 01h
    xor cx, cx
    xor dx, dx
    int 21h

    mov pos_high, dx; dx:ax - original
    mov pos_low, ax

    mov ah, 42h; lseek to mass[size - 1]
    mov al, 02h
    xor cx, cx
    xor dx, dx
    int 21h

    ;for (int i = size - 1; i >= original; --i)
    ;{
    ;   mass[i + n] = mass[i]
    ;}

    insert_in_file_loop:
        ;mass[i + n] = mass[i]
        mov ah, 42h; save current pos (mass[i])
        mov al, 01h
        xor cx, cx
        xor dx, dx                                       
        int 21h                                          
        push ax
        push dx

        mov ah, 3Fh; read char
        mov cx, 1
        mov dx, offset buf
        int 21h

        mov ah, 42h; lseek to (mass[i + n])
        mov al, 01h
        xor cx, cx
        mov dx, di                ; di = n
        int 21h

        mov ah, 40h; write char
        mov cx, 1
        mov dx, offset buf
        int 21h

        ;if (i == original)
        ;   break;
        mov ah, 42h; restore current pos (mass[i])
        mov al, 00h
        pop cx                                                
        pop dx
        int 21h

        cmp dx, pos_high
        jne insert_in_file_loop_continue
        cmp ax, pos_low
        jne insert_in_file_loop_continue
        jmp insert_in_file_extended

        ;i = i - 1;
        insert_in_file_loop_continue:
        mov ah, 42h; lseek to before current (mass[i - 1])
        mov al, 01h
        mov cx, 0FFFFh
        mov dx, -1
        int 21h

        jmp insert_in_file_loop

    insert_in_file_extended:
    mov ah, 42h; restore original pos
    mov al, 00h
    mov cx, pos_high
    mov dx, pos_low
    int 21h

    mov dx, offset buf
    insert_in_file_insert_loop:
        lodsb
        cmp al, 0
        je insert_in_file_end
        mov ah, 40h
        mov cx, 1
        mov buf, al
        int 21h
        jmp insert_in_file_insert_loop

    insert_in_file_end:

    pop di
    pop cx
    pop dx
    pop ax
    ret


endp

delete_from_file proc; bx - file descr, cx - size
    push ax
    push dx
    push cx
    push di

    mov di, cx

    mov ah, 42h; save original pos
    mov al, 01h
    xor cx, cx
    xor dx, dx
    int 21h

    mov pos_high, dx; dx:ax - original
    mov pos_low, ax

    delete_from_file_loop:
        mov ah, 42h; save current pos (mass[i])
        mov al, 01h
        xor cx, cx
        xor dx, dx
        int 21h
        push ax
        push dx

        mov ah, 42h; lseek to mass[i + n]
        mov al, 01h
        xor cx, cx
        mov dx, di
        int 21h

        mov ah, 3Fh; read char
        mov cx, 1
        mov dx, offset buf
        int 21h

        cmp ax, 0
        je delete_from_file_eof

        mov ah, 42h; restore current pos
        mov al, 00h
        pop cx
        pop dx
        int 21h

        mov ah, 40h; write char
        mov cx, 1
        mov dx, offset buf
        int 21h

        jmp delete_from_file_loop

    delete_from_file_eof:
    mov ah, 42h; restore current pos
    mov al, 00h
    pop cx
    pop dx                                       
    int 21h

    mov ah, 40h; truncate file
    mov cx, 0
    mov dx, offset buf
    int 21h

    delete_from_file_end:
    mov ah, 42h; restore original pos
    mov al, 00h    
    mov cx, pos_high
    mov dx, pos_low
    int 21h

    pop di
    pop cx
    pop dx
    pop ax
    ret
endp

min proc; al - a, ah - b; output: bl - min
    cmp al, ah
    jae min_end
    mov bl, al
    ret
    min_end:
    mov bl, ah
    ret
endp

point_to_next proc; bx - file descr
    push ax
    push cx
    push dx
    mov ah, 42h 
    mov al, 01h
    xor cx, cx
    mov dx, 1
    int 21h
    pop dx
    pop cx
    pop ax
    ret
endp

check_if_str proc; bx - file descr, di - str; output: c set if str
    push ax
    push bx
    push cx
    push dx
    push di
    push si

    mov si, di

    mov ah, 42h
    mov al, 01h
    xor cx, cx
    xor dx, dx
    int 21h
    push ax
    push dx

    check_if_str_loop:
        lodsb
        cmp al, 0
        je check_if_str_yes            ; if end || in file and str
        mov di, ax

        mov ah, 3Fh
        mov cx, 1
        mov dx, offset buf
        int 21h
        cmp ax, 0
        je check_if_str_eof
        mov ax, di
        cmp al, buf                   ; if symbol exists
        jne check_if_str_no
        jmp check_if_str_loop
        
    check_if_str_eof:
    mov EOF, 1
    jmp check_if_str_no

    check_if_str_yes:
    mov ah, 42h
    mov al, 00h
    pop cx
    pop dx
    int 21h
    stc
    jmp check_if_str_end

    check_if_str_no:
    mov ah, 42h
    mov al, 00h
    pop cx
    pop dx
    int 21h
    clc
    jmp check_if_str_end

    check_if_str_end:

    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
endp

printz proc
    printz_loop:
        lodsb
        cmp al, 0
        je printz_end
        mov ah, 02h
        mov dl, al
        int 21h
        jmp printz_loop
    printz_end:
    ret
endp

print macro str
    mov ah, 09h
    mov dx, offset str
    int 21h
endm

println macro str
    mov ah, 09h
    mov dx, offset str
    int 21h
    mov ah, 02h
    mov dl, 0Dh
    int 21h
    mov ah, 02h
    mov dl, 0Ah
    int 21h
endm

printlnz macro str
    mov si, offset str
    call printz
    mov ah, 02h
    mov dl, 0Dh
    int 21h
    mov ah, 02h
    mov dl, 0Ah
    int 21h
endm

strlen proc; di - str; output: cx - length
    push si
    ;push di
    push ax
    mov si, di
    xor cx, cx

    strlen_loop:
        lodsb
        cmp al, 0
        je strlen_end
        inc cx
        jmp strlen_loop
    
    strlen_end:
    pop ax
    pop si
    ret
endp

start:
    mov ax, @data
    mov ds, ax
    mov es, ax

    call parse_command_line
    jc _error_wrong_args

    print message_file_path
    printlnz file_path
    print message_old_str
    printlnz old_str
    print message_new_str
    printlnz new_str

    mov ah, 3Dh
    mov al, 0010010b           ;10 - for red and write, 001 - denied for other
    mov dx, offset file_path
    int 21h
    jc _error_file
    mov bx, ax

    call replace_strings       ;bx - file name

    mov ah, 3Eh
    int 21h
    jc _error_file

    jmp _end

    _error_wrong_args:
    print wrong_args
    jmp _end

    _error_file:
    cmp ax, 01h
    je _error_function_number_invalid
    cmp ax, 02h
    je _error_file_not_found
    cmp ax, 03h
    je _error_path_not_found
    cmp ax, 04h
    je _error_too_many_open_files
    cmp ax, 05h
    je _error_access_denied
    cmp ax, 0Ch
    je _error_access_code_invalid
    cmp ax, 56h
    je _error_invalid_password
    print unidentifyed_error
    jmp _end

    _error_function_number_invalid:
    print function_number_invalid
    jmp _end
    _error_file_not_found:
    print file_not_found
    jmp _end
    _error_path_not_found:
    print path_not_found
    jmp _end
    _error_too_many_open_files:
    print too_many_open_files
    jmp _end
    _error_access_denied:
    print access_denied
    jmp _end
    _error_invalid_handle:
    print invalid_handle
    jmp _end
    _error_access_code_invalid:
    print access_code_invalid
    jmp _end
    _error_invalid_password:
    print invalid_password
    jmp _end

    

    _end:
    mov ax, 4C00h
    int 21h
end start