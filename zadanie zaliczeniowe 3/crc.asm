global _start

; Poniższy program oblicza sumę kontrolną danych zawartych w pliku z dziurami.
; Rozwiązanie to bazuje na tzw. "lookup table", tzn. tablicy o rozmiarze 256
; bajtów, wypełnionej obliczonymi wcześniej wartościami sum kontrolnych dla
; każdej możliwej wartości bajtu.

;Poniżej znajdują się następujące stałe:

BUFFER_SIZE equ 65536                   ; Stała określająca rozmiar bufora.
                                        ; Przyjmuję rozmiar 64kb za optymalny,
                                        ; ponieważ z racji, że długość danych we
                                        ; fragmencie wyrażona jest jako
                                        ; dwubajtowa liczba, nie przekracza
                                        ; ona wartości 2^16. Zatem taki rozmiar
                                        ; pozwala na jednorazowe wczytanie danych
                                        ; we fragmencie.

; Stałe przechowujące numer odpowiedniej funkcji systemowej:
SYS_READ     equ 0
SYS_WRITE    equ 1
SYS_OPEN     equ 2
SYS_CLOSE    equ 3
SYS_LSEEK    equ 8
SYS_EXIT     equ 60

ERROR_CODE   equ 1                      ; Stała przechowująca kod błędu.
POLLEN       equ 64                     ; Stała przechowująca maksymalną długość
                                        ; wielomianu.
READ_ONLY    equ 0                      ; Stała przechowująca tryb otwarcia pliku.

section .data

zero: db '0'                            ; Zmienne przechowujące znaki 0, 1 oraz
one: db '1'                             ; \n, wykorzystywane przy wypisywaniu
nextline: db `\n`                       ; wyniku.

section .bss

buffer: resb BUFFER_SIZE                ; Rezerwowanie pamięci na bufor.
table: resq 256                         ; Rezerwowanie pamięci na tablicę
                                        ; o rozmiarze 256 liczb 64-bitowych.

section .text


_start:

    mov r8, [rsp]                       ; Ładowanie do rcx liczby parametrów
                                        ; [nazwa programu + argumenty].
    cmp r8, 3                           ; Sprawdzanie, czy liczba parametrów
                                        ; wynosi 3.
    jne .error_without_sysclose         ; Jeśli nie, to zamykamy program z błedem.
    mov r9, [rsp + 16]                  ; Ładowanie nazwy pliku do r9.
    mov rbx, [rsp + 24]                 ; Ładowanie wielomianu do r10.

; Poniżej znajduje się kod obliczający długość wielomianu.
    xor   al, al
    mov   ecx, POLLEN + 1
    mov   rdi, rbx
    repne scasb
    sub   rdi, rbx
    sub   rdi, 1
    mov r13, rdi                        ; Ładowanie do r13 długości wielomianu.
    cmp r13, 0                          ; Sprawdzanie, czy długość wielomianu
                                        ; jest większa od 0.
    je .error_without_sysclose          ; Jeśli nie, to wykrywamy błąd.
    xor r10, r10                        ; Inicjowanie rejestru, który będzie
                                        ; przechowywał wielomian.
    xor r11, r11                        ; Inicjowanie rejestru pomocniczego,
                                        ; liczącego obsłużone znaki.

; Poniżej znajduje się kod zapisujący wielomian w rejestrze r10.
.parse_polonymial:
    shl r10, 1                          ; Przesuwanie bitów w rejestrze r10
                                        ; o 1 bit w lewo, aby przygotować
                                        ; miejsce na pozycji najmniej znaczącego
                                        ; bitu dla nowo wczytanej wartości.
    xor al, al                          ; Usuwanie dotychczasowej zawartości al.
    mov al, byte [rbx + r11]            ; Ładowanie do al kolejnego znaku.
    cmp al, '1'                         ; Sprawdzanie, czy wczytany znak to 1.
    jne .not_one                        ; Jeśli nie, to przechodzimy do kolejnego
                                        ; etapu.
    inc r10                             ; Jeśli tak, to zwiększamy zawartość r10
                                        ; o 1, powodując dopisanie jedynki na
                                        ; ostatniej pozycji.
    jmp .end_parsing

.not_one:                               ; Sekcja, do której program trafia, Jeśli
                                        ; wczytany znak okazał się nie być 1.
    cmp al, '0'                         ; Sprawdzanie, czy wczytany znak to 0.
    jne .error                          ; Jeśli nie, to oznacza, że wielomian
                                        ; jest nieprawidłowy, bo zawiera znak
                                        ; różny od 0 i 1. Natomiast w przeciwnym
                                        ; przypadku, nic nie trzeba robić, ponieważ
                                        ; dopisanie 0 wykonuje się na początku
                                        ; podczas polecenia shl o 1.

.end_parsing:
    inc r11                             ; Zwiększanie liczby obsłużonych znaków.
    cmp r11, r13                        ; Sprawdzanie, czy został już obsłużonych
                                        ; cały wielomian.
    jne .parse_polonymial

; Poniższy fragment kodu wykonuje logiczne przesunięcie wielomianu
;  o długość = 64 - długość wielomianu w lewo, tak aby wielomian znajdłował
; się w rejestrze na najbardziej znaczących bitach.
.shl_polonymial:
    mov ecx, 64
    sub ecx, r13d
    shl r10, cl

; Poniżej znajduje się kod uzupełniający tablicę table od ostatniego do
; pierwszego indeksu.
    mov rcx, 256                        ; ładowanie do rcx liczby wszystkich
                                        ; możliwych bajtów.
.table_loop:
    dec rcx                             ; Zmniejszanie zawartości rcx, który
                                        ; przechowuje numer aktualnie obsługiwanego
                                        ; indeksu.
    js .next_step                       ; Jeśli rcx mniejsze od zera, to
                                        ; przechodzimy do następnego etapu.
    mov r11, rcx                        ; Kopiujemy wartość rcx do r11,
                                        ; aby ten rejestr przechowywał obliczane
                                        ; crc.

    shl r11, 56                         ; Przesuwanie bajtu na najbardziej znaczący
                                        ; bajt w r11.
    mov rax, 8                          ; Ładowanie do rax 8, ponieważ o tyle
                                        ; bitów będziemy przesuwać rejestr r11
                                        ; w lewo.

.counting_crc_loop:
    dec rax
    js .crc_result                      ; Jeśli wartość w rax jest mniejsza od 0,
                                        ; to przechodzimy dalej.
    shl r11, 1                          ; Przesuwamy r11 o 1 bit w lewo.
    jnc .counting_crc_loop              ; Jeżeli flaga CF nie została ustawiona
                                        ; na 1, to powtarzamy krok.
    xor r11, r10                        ; W przeciwnym przypadku wykonanie xor
                                        ; z wielomianem.
    jmp .counting_crc_loop              ; Powtarzanie kroku.

.crc_result:
    lea r12, [rel table]
    mov qword [r12 + 8 * rcx], r11      ; Ładowanie obliczonej sumy kontrolnej
                                        ; dla danego bajtu do tablicy pod indeksem
                                        ; równym wartości tego bajtu.
    jmp .table_loop

; Poniższy kod otwiera plik.
.next_step:
    mov rax, SYS_OPEN                   ; Ładowanie do rax numeru funkcji
                                        ; systemowej sys_open.
    mov rdi, r9                         ; Kopiowanie wartości r9 do rdi, czyli
                                        ; nazwy pliku.
    mov rdx, READ_ONLY                  ; Ładowanie do rdx trybu otwarcia pliku.
    syscall
    cmp rax, 0                          ; Sprawdzanie wyniku funkcji systemowej.
    js .error                           ; Jeśli wynik jest < 0, to
                                        ; sygnalizujemy błąd.
    mov r10, rax                        ; Przechowywanie deskryptoru pliku.
    xor r14, r14                        ; Inicjowanie rejestru r14, który będzie
                                        ; przetrzymywał CRC.

; Poniższy kod odczytuje dane z pliku.
.read_loop:
    xor r12, r12                        ; Inicjowanie rejestru r12 na 0, gdyż
                                        ; będzie przechowywał informację
                                        ; o długości aktualnie obsługiwanego
                                        ; fragmentu.
    mov rax, SYS_READ
    mov rdi, r10                        ; Ładowanie deskryptoru pliku do rdi.
    mov rsi, buffer                     ; Ładowanie adresu bufora.
    mov rdx, 2                          ; Czytanie 2 bajtów.
    syscall
    cmp rax, 0                          ; Sprawdzanie wyniku funkcji systemowej.
    js .error                           ; Sygnalizowanie błedu.
    add r12, rax                        ; Dodawanie liczby przeczytanych bajtów.
    xor edx, edx
    mov dx, word [rel buffer]           ; Ładowanie długości danych we
                                        ; fragmencie.
    mov rax, SYS_READ
    mov rdi, r10                        ; Ładowanie deskryptoru pliku.
    mov rsi, buffer                     ; Ładowanie adresu bufora.
    syscall
    cmp rax, 0                          ; Sprawdzanie poprawności działania
                                        ; funkcji systemowej.
    js .error
    add r12, rax                        ; Dodawanie liczby przeczytanych bajtów.
    xor r15, r15                        ; Inicjowanie rejestru
    mov r15, -1

; Poniższy kod oblicza crc dla wczytanego fragmentu danych za pomocną
; tzw. "lookup table"
.crc_loop:
    inc r15
    cmp r15, rax                        ; Sprawdzanie czy zostały obsłużone
                                        ; wszystkie bajty.
    je .read_next
    xor ecx, ecx
    lea rbx, [rel buffer]
    mov cl, [rbx + r15]                 ; ładowanie co rcx kolejnego bajtu.
    shl rcx, 56                         ; Przesuwanie wczytanego bajtu, tak aby
                                        ; znalazł się w rejestrze na najbardziej
                                        ; znaczącym bajcie.
    xor r14, rcx                        ; Xor-owanie bajtu z aktualnym crc.
    mov rcx, r14                        ; Kopiowanie wyniku do rcx.
    shr rcx, 56                         ; Przesuwanie wyniku w prawo, tak aby
                                        ; najbardziej znaczący bajt znalazł się
                                        ; na pozycji najmniej znaczącego bajtu.
    lea rbx, [rel table]
    mov rcx, qword [rbx + 8 * rcx]      ; Odczytywanie zawartości tablicy spod
                                        ; indeksu będącego poprzednią zawartością
                                        ; rcx.
    shl r14, 8                          ; Przesuwanie rejestru r14 o 8 w lewo,
                                        ; symulując obliczanie nowego crc,
    xor r14, rcx                        ; poprzez operację xor z pobraną
    jmp .crc_loop                       ; zawartością tablicy.

; Poniższy kod realizuje czytanie długości przesunięcia oraz dokonuje go, Jeżeli
; przesunięcie to nie wskazuje na początek aktualnego fragmentu.
.read_next:
    mov rax, SYS_READ
    mov rdi, r10                        ; Ładowanie deskryptora pliku.
    mov rsi, buffer
    mov rdx, 4                          ; Ładowanie liczby bajtów do przeczytania.
    syscall
    cmp rax, 0                          ; Sprawdzanie poprawności funkcji sys_read.
    js .error
    add r12, rax                        ; Dodawanie liczby przeczytanych bajtów.
    add r12D, dword [rel buffer]        ; Dodawanie do długości fragmentu wartość
                                        ; przesunięcia. Jeżeli wartość ta okaże
                                        ; się być 0, to oznacza, że przesunięcie
                                        ; wskazuje na aktualny fragment.
    jz .finish_reading
    mov rax, SYS_LSEEK
    mov rdi, r10                        ; Ładowanie deskryptora pliku.
    xor esi, esi
    movsx rsi, dword [rel buffer]       ; Ładowanie do rsi, długości przesunięcia.
    mov rdx, 1                          ; Ładowanie do rdx jedynki, która oznacza,
                                        ; że przesunięcie ma się dokonać od
                                        ; aktualnego miejsca w pliku.
    syscall
    cmp rax, 0                          ; Sprawdzanie poprawności funkcji sys_lseek.
    js .error
    jmp .read_loop

.finish_reading:
    mov r15, r13                        ; Ładowanie do pomocniczego rejestru r15
                                        ; długości wielomianu.
    dec r15

; Poniższy kod wypisuje wynikowe crc.
.writing_result:
    shl r14, 1                          ; Przesuwanie wyniku o 1 bit w lewo.
    jc .write_1                         ; Jeśli został ustawiony znacznik CF,
                                        ; to znaczy, że "wyrzuconym" bitem była
                                        ; jedynka. Natomiast w przeciwnym
                                        ; przypadku jest nim 0.
    mov rax, SYS_WRITE                  ; Wywoływanie funkcji systemowej sys_write
    mov rdi, 1                          ; do wypisania na wyjście znaku '0'.
    mov rsi, zero
    mov rdx, 1
    syscall
    cmp rax, 0                          ; Sprawdzanie poprawności funkcji sys_write.
    jz .error
    js .error
    dec r15
    jns .writing_result
    jmp .exit

.write_1:
    mov rax, SYS_WRITE                  ; Wywoływanie funkcji systemowej sys_write
    mov rdi, 1                          ; do wypisania na wyjście znaku '1'.
    mov rsi, one
    mov rdx, 1
    syscall
    cmp rax, 0                          ; Sprawdzanie poprawności funkcji sys_write.
    jz .error
    js .error
    dec r15
    jns .writing_result
    jmp .exit

; Poniższy kod obsługuje zakończenie programu z błędem, gdy plik nie został
; otworzony.
.error_without_sysclose:
    mov eax, SYS_EXIT
    mov edi, ERROR_CODE
    syscall

; Poniższy kod obsługuje zakończenie programu z błędem, gdy plik został już
; otworzony.
.error:
    mov rax, SYS_CLOSE
    mov rdi, r10
    syscall
    mov eax, SYS_EXIT
    mov edi, ERROR_CODE
    syscall

; Poniższy kod obsluguje zakończenie programy bez błędu wraz z zamknięciem pliku.
; Ponadto przed zamknięciem dokonuje wypisania znaku końca wiersza.
.exit:
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, nextline
    mov rdx, 1
    syscall
    cmp rax, 0
    js .error
    mov rax, SYS_CLOSE
    mov rdi, r10
    syscall
    cmp rax, 0
    js .error
    mov eax, SYS_EXIT
    xor edi, edi
    syscall