global mdiv

section .text

mdiv:
    test rdx, rdx                   ;Sprawdzanie czy dzielnik jest zerem.
    jz   .div_by_zero

    ;Inicjalizowanie rejestrów.
    mov  r8B, 2                     ; Informuje, czy wynik ma być ujemny.
    xor  r11B, r11B                 ; Informuje o miejscu programu.
    mov  r9, rdx                    ; r9 = y (dzielnik)
    xor  r10, r10                   ; Przechowuje liczbę 0.
    dec  rsi
    mov  rcx, rsi                   ; Przechowuje indeks ostatniego elementu.
    cmp  qword [rdi + 8 * rcx], r10 ; Sprawdzanie czy liczba jest ujemna.
    js   .negative_dividend
    xor  r8B, r8B                   ; Sygnalizowanie o dodatniej dzielnej.

.negative_divisor:                  ; Sprawdzanie czy dzielnik jest ujemny.
    cmp  r9, r10                    ; Jeśli tak, to zmienianie go na dodatni.
    jns  .division
    inc  r8B                        ; Sygnalizowanie wystąpienia minusa.
    not  r9
    inc  r9

.division:                          ; Rozpoczęcie etapu dzielenia.
    mov  rcx, rsi
    inc  r11B                       ; Sygnalizowanie o przejściu do działania.
    xor  edx, edx

.division_loop:                     ; Pętla wykonująca dzielenie.
    mov  rax, [rdi + 8 * rcx]
    div  r9
    mov  [rdi + 8 * rcx], rax
    dec  rcx
    jns  .division_loop             ; Wykonywanie pętli dopóki indeks >= 0.
    mov  rax, rdx
    mov  rcx, rsi
    cmp  r8B, r10B
    jz   .done                      ; Dzielna i dzielnik dodatnie.
    cmp  r8B, 3
    jz   .checking_result           ; Dzielna i dzielnik ujemne, więc trzeba
                                    ; spawdzić czy znak wyniku się zgadza.

.negative_dividend:                 ; Pętla negująca wszystkie bity dzielnej.
    not  qword [rdi + 8 * rcx]
    dec  rcx
    jns  .negative_dividend
    jmp  .add_1_dividend

.change_to_zero:                    ; Zmienianie liczby na 0.
    mov  qword [rdi + 8 * rcx], r10

.add_1_dividend:                    ; Pętla dodająca 1 do dzielnej.
    inc  rcx
    cmp  qword [rdi + 8 * rcx], 0xFFFFFFFFFFFFFFFF
    jz   .change_to_zero
    inc  qword [rdi + 8 * rcx]
    cmp  r11B, r10B
    jz   .negative_divisor          ; Jeśli etap przed wykonaniem dzielenia, to
    cmp  r8B, 2                     ; sprawdzenie znaku dzielnika.
    js   .done

.changing_remainder:                ; Zmiana znaku reszty.
    not  rax
    inc  rax
    mov  rcx, rsi
    inc  rcx
    ret

.checking_result:                   ; Sprawdzanie czy znak wyniku się zgadza.
    mov  rcx, rsi
    cmp  qword [rdi + 8 * rcx], r10
    jns  .changing_remainder

.div_by_zero:                       ; Przypadek nadmiaru.
    xor  edx, edx                   ; Zgłoszenie przerwania 0.
    div  rdx

.done:
    ret
