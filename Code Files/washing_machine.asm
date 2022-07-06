#make_bin#

#LOAD_SEGMENT=FFFFh#
#LOAD_OFFSET=0000h#

#CS=0000h#
#IP=0000h#

#DS=0000h#
#ES=0000h#

#SS=0000h#
#SP=FFFEh#

#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#

        jmp     st1 
        nop  
;These two commands take up 4 bytes (3+1)

;INT 1 is not used, so 1 x4 = 00004h - it is stored with 0
        dw      0000
        dw      0000
		
;STOP - is used as nmi - IP value points to STOP_INT and CS value will remain at 0000h
        dw      STOP_INT
        dw      0000
		
;INT 3 to INT 255 is not used, so IP and CS intialized to 0000h, so, that occupies (255-3+1)*4=1012 bits
		 
        db     1012 dup(0)

;main program

		st1:	  cli
		
; intialize ds, es,ss to start of RAM

        mov       ax,0200h
        mov       ds,ax
        mov       es,ax
        mov       ss,ax
        mov       sp,0FFFEH

		;initialize 8255
        mov     al,10000011b
        out     06h,al

		;initialize 8253(1) - COUNTER0 in mode 3
        mov     al,00110110b
        out     16h,al

        ;initialize 8253(1) - COUNTER1 in mode 3
        mov     al,01110110b
        out     16h,al

        ;initialize 8253(1) - COUNTER2 in mode 1
        mov     al,10110010b
        out     16h,al
		
        ;initialize 8253(2) - COUNTER0 in mode 1
        mov     al,00110010b
        out     26h,al	
		
        ;initialize 8253(2) - COUNTER1 in mode 1
        mov     al,01110010b
        out     26h,al

        ;initialize 8253(2) - COUNTER2 in mode 3
        mov     al,10110110b
        out     26h,al

        ;Wait until load button is pressed
        
		;Load is pressed for the first time
		;dl keeps count of the number of times user presses LOAD
start:  mov     dl,00h								
X0:	    in 	    al,04h
	    and 	al,01h
	    jz	    X0
	    inc 	dl
	    CALL    DEBOUNCE
		
		
		;Checking if there are more LOAD presses 
X1:     in      al,04h
        and     al,01h
        
        jz      X2
        cmp     dl,3       
        ;Resetting the count after 3 presses
        jne     Z1
        mov     dl,00h 
        
        ;incrementing load count
Z1:     inc     dl
        
        ;poll for START input
X2:     in      al,04h
        and     al,02h
        jnz     X3
        CALL    DEBOUNCE
        
        jmp     X1 


        ;loading count to set the alarm freq - 0.5 Hz
X3:      mov    bx,02h
        
        ;DOOR_CHK is used to check if the door is locked
        ;if not raise an alarm and wait for door close
        call    DOOR_CHK

X4:     ;locking the door(latch)
        mov     al,01h
        out     00h,al

        ;checking wash mode
        mov     ah, dl  
        
        ;Load count into 8253(1) COUNTER0 - 61A8h = 25,000
        mov     al,0a8h
        out     10h,al

        mov     al,61h
        out     10h,al

        ;Load count into 8253(1) COUNTER1 - 64h = 100
        mov     al,64h
        out     12h,al

        mov     al,00h
        out     12h,al

        ;ah has the wash mode value
        cmp     ah,01h
        jne     Y1     
        call    LIGHT

Y1:     cmp     ah,02h
        jne     Y2     
        call    MED

Y2:     cmp     ah,03h  
        jne     Y3 
        call    HEAVY

Y3:     ;end routine
        jmp     start

   
;Procedure for Light mode of Operation:   
LIGHT 	proc near    

        ;Begin Rinse Cycle 
        
        call    WATER_IN

        ;Load the required count in dx: 78h = 120s - Rinse for 2 mins
        mov     dl,78h
        mov     dh,00h  
        
        call    RINSE
        
        call    WATER_OUT
		
		
        ;Begin Wash Cycle
        
        call    WATER_IN 

        ;Load the required count in dx: 0b4h = 180s -Wash for 3 mins
        mov     dl,0b4h
        mov     dh,00h
		
        call    WASH

        call    WATER_OUT
		

        ;Begin Rinse Cycle (2nd)
		
        call    WATER_IN

        ;Load the required count in dx: 78h = 120s - Rinse again for 2 mins
		mov 	dl,78h
        mov     dh,00h
		
        call    RINSE
		
        call    WATER_OUT


        ;Begin Dry Cycle

        ;Load the required count in dx: 78h = 120s - Dry for 2 mins
        mov     dl,78h
        mov     dh,00h
		
        call    DRY 
        
        call    DELAY1
		
		;Sound buzzer at the end of a complete cycle
        call    BUZZER_1
        
		;Open lock at the end of the complete cycle
		call    OPEN_LOCK
        
		
        ret     
        LIGHT endp

;Procedure for Medium mode of Operation:
MED		proc near 
    
        ;Begin Rinse Cycle
    
        call    WATER_IN

        ;Load the required count in dx: 0b4h = 180s - Rinse for 3 mins
        mov     dl,0b4h
        mov     dh,00h
		
        call    RINSE
        
        call    WATER_OUT
        

        ;Begin Wash Cycle

        call    WATER_IN 

        ;Load the required count in dx:	012ch = 300s - Wash for 5 mins
        mov     dl,2ch
        mov     dh,01h
		
        call    WASH

        call    WATER_OUT

        ;Begin Rinse Cycle (2)
        
        call    WATER_IN

        ;Load the required count in dx: 0b4h = 180s - Rinse again for 3 mins
        mov     dl,0b4h
        mov     dh,00h
        
		call    RINSE

        call    WATER_OUT

        ;Begin Dry Cycle

        ;Load the required count in dx: f0h = 240s - Dry for 4 mins
        mov     dl,0f0h
        mov     dh,00h

        call    DRY
		
		;Sound buzzer at the end of a complete cycle
        call    BUZZER_1
		
		;Open lock at the end of the complete cycle
        call    OPEN_LOCK


        ret     
        MED endp

;Procedure for Medium mode of Operation:
HEAVY	proc near 
    
        ;Begin Rinse Cycle
    
        call    WATER_IN

        ;Load the required count in dx: 0b4h = 180s - Rinse for 3 mins
        mov     dl,0b4h
        mov     dh,00h
		
        call    RINSE
       
        call    WATER_OUT 
        

        ;Begin Wash Cycle
       
        call    WATER_IN 

        ;Load the required count in dx: 012ch = 300s - Wash for 5 mins
        mov     dl,2ch
        mov     dh,01h
		
        call    WASH

        call    WATER_OUT

        ;Begin Rinse Cycle (2)
        
        call    WATER_IN

        ;Load the required count in dx: 0b4h = 180s - Rinse again for 3 mins
        mov     dl,0b4h
        mov     dh,00h
		
        call    RINSE
		
        call    WATER_OUT

        ;Begin Wash Cycle (2)
        
        call    WATER_IN 

        ;Load the required count in dx: 012ch = 300s - Wash again for 5 mins
        mov     dl,2ch
        mov     dh,01h
		
        call    WASH

        call    WATER_OUT

        ;Begin Rinse Cycle (3)
        
        call    WATER_IN

        ;Load the required count in dx: 0b4h = 180s - Rinse again for 3 mins
        mov     dl,0b4h
        mov     dh,00h
		
        call    RINSE
		
        call    WATER_OUT

        ;Begin Dry Cycle
        
        ;Load the required count in dx: 0f0h = 240s -Dry for 4 mins
        mov     dl,0f0h
        mov     dh,00h
		
        call    DRY 
        
		;Sound buzzer at the end of a complete cycle
        call    BUZZER_1

		;Open lock at the end of the complete cycle
        call    OPEN_LOCK


        ret     
        HEAVY endp
		
; Procedure to open the water in relay and check is water is full
WATER_IN proc near

        ;open water-input relay
W_IN0:  mov     al,00000011b
        out     00h,al

        ;Wait for 10 min, for water to get filled. Load count 0258h = 600s 
        mov     al,58h
        out     22h,al

        mov     al,02h
        out     22h,al

        ;Enabling counter gates - PC5
        mov     al,00100000b
        out     04h,al
                      
        ;CLOCK EDGE DELAY
        CALL    DELAY1

W_IN1:  ; Poll for counter output
        in      al,02h
        and     al,01000000b
        jnz     W_IN2
		
        ;check if adequate amount of water is filled
        in      al,02h
        and     al,00000001b

        jnz     W_IN3
        jmp     W_IN1

W_IN2:  ;alarm sound

        ;gates disable
        mov     al,00h
        out     04h,al

        ;Wait till the user resumes, call stop routine
        ;load count to set the frequency of the buzzer to notify the user of an issue - buzzer freq=1 Hz
        mov     bx,01h

        call    STOP_R
        jmp     W_IN0

W_IN3:  ;close water-in valve after water is full
        mov     al,00000001b 
        out     00h,al

        ;gates disable
        mov     al,00h
        out     04h,al


        ret
        WATER_IN  endp

;Procedure to open the water out relay and check if water is empty
WATER_OUT proc near

        ;open water-output relay
W_OUT0: mov     al,00000101b
        out     00h,al

        ;Wait for 10 min, for water to get filled. Load count 0258h = 600s
        mov     al,58h
        out     22h,al

        mov     al,02h
        out     22h,al

        ;Enabling counter gates- PC5
        mov     al,00100000b
        out     04h,al
        
		;CLOCK EDGE DELAY
        CALL    DELAY1

W_OUT1: ; Poll for counter
        in      al,02h
        and     al,01000000b
        jnz     W_OUT2
		
        ;check if adequate amount of water is filled
        in      al,02h
        and     al,00000010b
        
        jnz     W_OUT3
        jmp     W_OUT1

W_OUT2: ; alarm sound

        ;Wait till the user resumes, call stop routine
        ;load count to set the frequency of the buzzer
        mov     bx,01h

        call    STOP_R
        jmp     W_OUT0
        
W_OUT3: ;close water-in valve after water is full
        mov     al,00000001b 
        out     00h,al

        ;gates disable
        mov     al,00h
        out     04h,al


        ret
        WATER_OUT  endp

;Procedure for Rinse cycle
RINSE   proc near

        ;dx has the count value for time
	    
		;LSB
        mov	    al,dl
	    out 	14h,al
        ;MSB
        mov     al,dh
        out     14h,al
	
	    ;Activate the gate of Counter (8253 (1) G2) for Agitator
	    ;This keeps the agitator active for the required time
	    mov	    al,00010000b
	    out	    04h,al
       
        ;Give a delay for the Counter to activate
	    ;Call delay      
	    CALL    DELAY1
	    
	    
R1:		;Start polling for o/p of CNTR to go low 
        in 	    al,02h
	    and	    al,00010000b
	    jz      R1	

        ;Then disable the counter gates (8253 (1) G2) - shut Agitator
	    mov	    al,00h
	    out	    04h,al


        ret
        RINSE   endp

;Procedure for Wash cycle
WASH    proc near

        ;dx has the count value for time
	
		;LSB
        mov		al,dl
		out 	14h,al
        ;MSB
        mov     al,dh
        out     14h,al
		
        ;Open detergent valve(relay)
        mov     al,00100001b
        out     00h,al
	
		;Activate the gate of Counter (8253 (1) G2) for Agitator
		;This keeps the agitator active for the required time
		mov		al,00010000b
		out		04h,al
       
        ;Give a delay for the CNTR to activate
		CALL 	DELAY1
		
		
        
W1:		;Start polling for o/p of CNTR to go low		
		in 	al,02h
		and	al,00010000b
		jz	W1
	
        ;Then disable the counter gates (8253 (1) G2) - Stops Agitator
		mov	al,00h
		out	04h,al

        ;detergent valve closed
        mov     al,00000001b
        out     00h,al


        ret
        WASH    endp

DRY     proc near

        ;dx has the count value for time
		
	    ;LSB
        mov	    al,dl
	    out 	20h,al
        ;MSB
        mov     al,dh
        out     20h,al
	
	    ;Activate the gate of CNTR (8253 (2) G0) for Revolving Tub
	    ;This keeps the revolving tub active for the required time
	    mov	    al,11000000b
	    out	    04h,al
       
        ;Give a delay for the CNTR to activate
	    CALL	DELAY1
		
		
D1:     ;Start polling for o/p of CNTR to go low
	    in 	    al,02h
	    and	    al,00100000b
	    jz	    D1
	
        ;Then disable the counter gates (8253 (2) G0) - Stop Revolving tub
	    mov	    al,00h
	    out	    04h,al


        ret
        DRY    endp

;Procedure for sounding the buzzer when the complete cycle ends
BUZZER_1 proc near

        ;sound buzzer for 10s
        ;load the count in 8253(2)
        mov     al,04h
        out     24h,al

        mov     al,00h
        out     24h,al

        ;gate enable, then delay, and then start counting
        ;gate enable for 8253(2)CNT2 - Frequency of the buzzer and 8253(1)CNT2- Time for which buzzer is sounded
        mov     al,10010000b     
        out     04h,al

        ;load count value for buzzer in 8253(1) CNT2
		
        ;LSB
        mov     al,0ah
        out     14h,al

        ;MSB
        mov     al,00h
        out     14h,al
        
        ;enable the buzzer
        mov     al,00001001b
        out     00h,al 
        
        ;Give a delay for the CNTR to activate
        CALL    DELAY1

B1:     ;Check if time (10s) is over
		in      al,02h
        and     al,00010000b
        jz      B1

        ;disable the gate
        mov     al,00h     
        out     04h,al 
        
        ;disable the buzzer
        mov     al, 01h
        out     00h,al


        ret
        BUZZER_1 endp

;Procedure to check if the door is closed by the user:
DOOR_CHK proc near
        
        ; bx has the count
        
		; LSB
        mov     al,bl
        out     24h,al
        ; MSB
        mov     al,bh
        out     24h,al

        ;check if door is open
        in      al,02h
        and     al,08h
        
        jnz     DC2
		
        ;sound buzzer
        ;enable alarm (Also enables buzzer)
        mov     al,10h
        out     00h,al

DC1:    ;check if door is open (ASSUMED REED SWITCH O/P IS DIGITAL)
        ;Buzzer is enabled until door closed
        in      al,02h
        and     al,08h
        jnz     DC2
        jmp     DC1    
        

DC2:   	;disable buzzer
        mov     al,00h
        out     00h,al
		
        ret
        DOOR_CHK  endp
		
;Procedure to open the latch holding the door:
OPEN_LOCK proc near

        mov     al,00h 
        out     00h,al
        
        ret
        OPEN_LOCK endp

;Stop when there is an issue with the washing machine. For example: when the water is not full due to some reason.
STOP_R	proc near	
	
        ;sound alarm (buzzer)

        ; bx has the count
		
        ; LSB
        mov     al,bl
        out     24h,al
        ; MSB
        mov     al,bh
        out     24h,al

        ;enabling buzzer
        mov     al,11h
        out     00h,al

S1:		in		al,02h
		and 	al,00000100b
		jz      S1

        ;disabling buzzer
        mov     al,01h
        out     00h,al
		
		ret
		STOP_R endp

;ISR for stop interrupt-NMI
STOP_INT:    
        
		;STOP ENABLE active 
        mov     al,00001111b
        out     06h,al
        
		;Open door latch
        mov     al,00h            
        out     00h,al

SI1:    ;poll until resume button is pressed
		in      al,02h
        and     al,00000100b
        jz      SI1

		;on pressing resume,close door latch
		mov 	al,01h
		out		00h,al
        
		;deactivate STOP ENABLE
        mov     al,00001110b
        out     06h,al


        iret
             

;Procedure for 2 second delay		 
DELAY1 proc near

;delay calculation
;no. of cycles for loop = 18 if taken/ 5 if not taken = 49,999x 18 +5
;no. of cycles for ret 16
;no. of cycles for call 19
;no. of cycles for mov 4 
;clock speed 1 MHz - 1 clock cycle 1us (micro seconds)
;total no.cycles delay = clkcycles for call + mov cx,imm + (content of cx-1)*18 + 5 + ret = (19 + 4 + (18*49,999) + 5 + 16)* 1 us = 0.900026s
;called 3 times, for approximately 2.7 seconds. 

        mov     cx,50000
deloop1: loop   deloop1  

        mov     cx,50000
deloop2: loop   deloop2

        mov     cx,50000
deloop3: loop   deloop3


        ret
        DELAY1 endp 
		
		
;Procedure for debounce delay
DEBOUNCE proc near

;delay calculation
;no. of cycles for loop = 18 if taken/ 5 if not taken = 14,999 x 18 + 5
;no. of cycles for ret 16
;no. of cycles for call 19
;no. of cycles for mov 4 
;clock speed 1 MHz - 1 clock cycle 1us (micro seconds)
;total no.cycles delay = clkcycles for call + mov cx,imm + (content of cx-1)*18+5 + ret= (19 + 4 + (18*14,999) + 5 + 16)* 1 us = 0.270026s
;adjusted for proteus, due to CPU load 
    
        mov     cx,15000
debloop1: loop  debloop1
    
	
        ret
        DEBOUNCE endp 










        


        


        





        

