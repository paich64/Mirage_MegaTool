.feature pc_assignment
.feature labels_without_colons
.feature c_comments

; -----------------------------------------------------------------------------------------------

; $000000 -> $000000: Lit(length = 21, F)
; $000001 -> $000015: Mat(offset = -12, length = 2, F)
; $000017 -> $000017: Lit(length = 1, F)
; $000017 -> $000018: Mat(offset = -5, length = 3, F)
; $000019 -> $00001b: Mat(offset = -11, length = 2, T)
; $00001a -> $00001d: Lit(length = 8, F)

.segment "ZEROPAGE" : zeropage

dc_bits		= $02
dc_get_zp	= $04

dloop
		jsr getnextbit									; after this, carry is 0, bits = 01010101
		bcs match

		jsr getlen										; Literal run.. get length. after this, carry = 0, bits = 10101010, A = 1
		sta z:dc_llen
		tay												; put length into y for addput

		sta $d707										; inline DMA copy
		.byte $00										; end of job options
		.byte $00										; copy
dc_llen	.word $0000										; count
dc_lsrc	.word $0000										; src
		.byte $00										; src bank
dc_ldst	.word $0000										; dst
		.byte $00										; dst bank
		.byte $00										; cmd hi
		.word $0000										; modulo, ignored

addget	clc
		tya
		adc z:dc_lsrc+0
		sta z:dc_lsrc+0
		lda z:dc_lsrc+1
		adc #$00
		sta z:dc_lsrc+1
		;lda z:dc_lsrc+2								; THIS SHOULD BE SAFE TO COMMENT OUT BECAUSE LSRC WILL NEVER CROSS THIS?
		;adc #$00
		;sta z:dc_lsrc+2

		jsr addput

		iny	
		beq dloop
														; has to continue with a match so fall through
match
		jsr getlen										; match.. get length.

		tax												; length 255 -> EOF
		inx
		beq dc_end

		stx z:dc_mlen

		lda #0											; Get num bits
		cpx #3
		rol
		jsr rolnextbit
		jsr rolnextbit
		tax
		lda z:offsets,x
		beq m8

:		jsr rolnextbit									; Get bits < 8
		bcs :-
		bmi mshort

m8		eor #$ff										; Get byte
		tay
		jsr getnextbyte
		bra mdone

		;.byte $ae ; = jmp mdone (LDX $FFA0)

mshort	ldy #$ff

mdone	;clc
								; HRMPF! HAVE TO DO THIS NASTY SHIT TO WORK AROUND DMA BUG :(((((
		ldx #$00				; assume source addressing is going to be linear
		cmp #$ff				; compare A with ff
		bne :+ 
		cpy #$ff				; compare Y with ff
		bne :+
		ldx #%00000010			; FFFF = -1 offset -> set source addressing to HOLD
:		stx z:dc_cmdh

		clc
		adc z:dc_mdst+0
		sta z:dc_msrc+0
		tya
		adc z:dc_mdst+1
		sta z:dc_msrc+1
		
		lda z:dc_mdst+2									; added for m65 for when we cross banks
		sta z:dc_msrc+2
		bcs :+
		dec z:dc_msrc+2
:		
		sta $d707										; inline DMA copy
		.byte $00										; end of job options
		.byte $00										; copy
dc_mlen	.word $0000										; count
dc_msrc	.word $0000										; src
		.byte $00										; src bank and flags
dc_mdst	.word $0000										; dst
		.byte $00										; dst bank and flags
dc_cmdh	.byte $00										; cmd hi
		.word $0000										; modulo, ignored

		ldy z:dc_mlen
		jsr addput

		;beq dc_end
		jmp dloop

dc_end
dc_jumpto
		jmp $c0de

; -----------------------------------------------------------------------------------------------

addput	clc
		tya
		adc dc_ldst+0
		sta dc_ldst+0
		lda dc_ldst+1
		adc #$00
		sta dc_ldst+1
		lda dc_ldst+2
		adc #$00
		sta dc_ldst+2

		clc
		tya
		adc dc_mdst+0
		sta dc_mdst+0
		lda dc_mdst+1
		adc #$00
		sta dc_mdst+1
		lda dc_mdst+2
		adc #$00
		sta dc_mdst+2
		rts

getlen	lda #1
glloop	jsr getnextbit
		bcc glend
		jsr rolnextbit									; if next bit is 1 then ROL the next-next bit into A
		bpl glloop										; if the highest bit is now still 0, continue. this means highest len is 255
glend	rts

rolnextbit
		jsr getnextbit
		rol												; rol sets N flag
		rts

getnextbit
		asl dc_bits
		bne dgend
		pha
		jsr getnextbyte
		rol
		sta dc_bits
		pla
dgend	rts

getnextbyte
		ldx z:dc_lsrc+3
		lda #$00
		sta z:dc_lsrc+3
		lda [dc_lsrc],z
		stx z:dc_lsrc+3
		inc z:dc_lsrc+0
		bne :+
		inc z:dc_lsrc+1
		bne :+
		inc z:dc_lsrc+2
:		rts

; -----------------------------------------------------------------------------------------------

offsets	.byte %11011111 ; 3		$DF						; short offsets
		.byte %11111011 ; 6     $FB
		.byte %00000000 ; 8		$00
		.byte %10000000 ; 10    $80
		.byte %11101111 ; 4		$EF						; long offsets
		.byte %11111101 ; 7     $FD
		.byte %10000000 ; 10    $80
		.byte %11110000 ; 13    $F0

; -----------------------------------------------------------------------------------------------
