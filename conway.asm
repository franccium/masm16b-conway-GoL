.386
instr SEGMENT use16
ASSUME cs:instr
update_conway PROC
	push ax
	push bx
	push es
	push cx

	mov eax, 0

	mov ax, 0A000H
	mov es, ax

	mov esi, 0 ; y
	mov edi, 0 ; x

	nastepny_wiersz:
		mov ax, cs:dlugosc_kolumny
		mov edx, esi
		mul dx
		mov bx, ax
		mov edi, 0

		nastepna_komorka:
			;mov ax, cs:dlugosc_kolumny
			;mov edx, edi
			;mul dx
			;add bx, ax
			; bx = row + col
			mov cs:obecna_komorka, bx
			cmp es:[bx], byte ptr 03H
			je alive
			
			; dead
			push eax
			call count_alive_neighbours
			mov ebp, eax
			pop eax

			cmp ebp, 3
			jne die
			jmp live

			alive:
			push eax
			call count_alive_neighbours
			mov ebp, eax
			pop eax

			cmp ebp, 2
			jb die
			je live
			cmp ebp, 3
			je live
			ja die


			die:
			mov al, cs:kolor_dead
			jmp koloruj

			live:
			mov al, cs:kolor_alive
			jmp koloruj

			koloruj:
			mov bx, cs:obecna_komorka
			mov es:[bx], al ; koloruj komorke

			inc bx
			inc edi
			cmp edi, 200
			jb nastepna_komorka
		inc esi ; y++
		cmp esi, 320
		jb nastepny_wiersz

	pop cx
	pop es
	pop bx
	pop ax
	jmp dword PTR cs:clock_handler_address

	; variables
	kolor_alive db 03H
	kolor_dead db 0
	adres_piksela dw 0
	przyrost dw 0
	obecna_komorka dw 0
	obecny_bx dw 0
	dlugosc_wiersza dw 320
	numer_wiersza dw 1
	dlugosc_kolumny dw 200
	numer_kolumny dw 1
	last_random_number dw 5823H ; initially the seed
	last_scaling_random_factor dw 392H
	use_preset_seed db 0H
	dead_spawn_chance dw 48000 ; percentage = x/2^16-1
	clock_handler_address dd ?
update_conway ENDP
	
count_alive_neighbours PROC
	push ebx
	push ecx
	push edx
	push ebp
	mov ebp, 0 ; alive neighbour count

	mov ecx, -1
	get_vertical_n:
		mov bx, cs:obecna_komorka

		mov ax, ds:dlugosc_kolumny
		mul cx ; 320 * -1 etc
		add bx, ax

		mov cs:obecny_bx, bx
		mov edx, -1
		get_horizontal_n:
			mov bx, cs:obecny_bx
			add bx, dx ; -320 -1 + 0 +1
			cmp bx, cs:obecna_komorka
			je continue
			cmp es:[bx], byte ptr 03H
			jne continue
			; alive neighbour found
			inc ebp

			continue:
			inc dx
			cmp dx, 2
			jb get_horizontal_n
		inc cx
		cmp cx, 2
		jb get_vertical_n

	mov eax, ebp ; eax = alive neighbour count

	pop ebp
	pop edx
	pop ecx
	pop ebx
	ret
count_alive_neighbours ENDP

generate_new_random_number1 PROC
	rol ax, 7            
	xor ax, 0CDEFH
	mov bx, cs:last_scaling_random_factor
	add bx, 213H
	ror bx, 2
	sub bx, 9285H
	rol bx, 12
	mov cs:last_scaling_random_factor, bx
	add ax, 5432H
	ror ax, 4 
	rcl ax, 13       
	add ax, 047AH 
	mov bx, cs:last_scaling_random_factor
	add bx, 213H
	ror bx, 2
	sub bx, 9285H
	rol bx, 12
	mov cs:last_scaling_random_factor, bx
	mul bx
	ror ax, 5           
	sub ax, 0DA43H    
	rcl ax, 9          
	
	cmp ax, 64000     
	jbe skip_capping  
	sub ax, 48000     
	skip_capping:
	ret
generate_new_random_number1 ENDP

generate_new_random_number2 PROC
	rol ax, 7            
	xor ax, 3A5FH
	mov bx, cs:last_scaling_random_factor
	add bx, 507H
	ror bx, 2
	sub bx, 0AD91H
	rol bx, 12
	mov cs:last_scaling_random_factor, bx
	add ax, 5432H
	ror ax, 4 
	rcl ax, 13       
	add ax, 40A2H 
	mov bx, cs:last_scaling_random_factor
	add bx, 394H
	ror bx, 2
	sub bx, 172DH
	rol bx, 12
	mov cs:last_scaling_random_factor, bx
	mul bx
	ror ax, 5           
	sub ax, 0A012H    
	rcl ax, 9          
	
	cmp ax, 64000     
	jbe skip_capping2
	sub ax, 48000     
	skip_capping2:
	ret
generate_new_random_number2 ENDP

start:
	mov ah, 0
	mov al, 13H
	int 10H
	mov bx, 0
	mov es, bx
	mov eax, es:[32]
	mov cs:clock_handler_address, eax
	push es

	mov esi, 0 ; y
	mov edi, 0 ; x
	mov ax, 0A000H
	mov es, ax

	mov dh, cs:use_preset_seed
	cmp dh, 1
	je preset_seed
	generate_seed:
	mov ah, 0
	int 1AH ; get system time
	xor dx, cx ; xor high and low word of clock ticks
	jmp nastepny_wiersz1
	preset_seed:
	mov dx, 5823H ; seed

	nastepny_wiersz1:
		mov ax, cs:dlugosc_kolumny
		mov edx, esi
		mul dx
		mov bx, ax
		mov edi, 0

		nastepna_komorka1:
			; bx = row + col
			mov ax, dx
			;rol ax, 3
			;xor ax, 03213H
			bt esi, 0
			jc nieparzysty_esi
			parzysty_esi:
			call generate_new_random_number1
			mov dx, ax      
			jmp komorki

			nieparzysty_esi:
			call generate_new_random_number2
			mov dx, ax    
			jmp komorki

			jmp komorki

			komorki:
			cmp dx, cs:dead_spawn_chance
			jc dead
			mov al, kolor_alive
			jmp kolor
			dead:
			mov al, kolor_dead

			kolor:
			mov es:[bx], al ; koloruj komorke

			inc bx
			inc edi
			cmp edi, 200
			jl nastepna_komorka1
		;inc esi ; y++
		inc esi
		cmp esi, 320
		jl nastepny_wiersz1

	pop es
	mov ax, SEG update_conway
	mov bx, OFFSET update_conway
	cli
	mov es:[32], bx
	mov es:[32+2], ax
	sti
	wait_for_input:
	mov ah, 1
	int 16h
	jz wait_for_input
	mov ah, 0
	mov al, 3H
	int 10H

	mov eax, cs:clock_handler_address
	mov es:[32], eax
	mov ax, 4C00H
	int 21H
instr ENDS
stack SEGMENT stack
db 256 dup (?)
stack ENDS
END start