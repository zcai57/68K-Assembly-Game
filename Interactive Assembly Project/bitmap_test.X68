*-----------------------------------------------------------
* Title      : 
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000    
TASK_PRINT  EQU 13
SENTINEL    EQU $deaddead
ALL_REG                 REG     d0-d7/d0-d6 

    INCLUDE "bitmap.X68"
    INCLUDE "GameManager.X68"
START:                  ; first instruction of program
    bsr     FillRegs
    bsr     switchEndianTestEven
    bsr     switchEndianTestOdd
    
    jsr     TestCheckCollision
    
    movem.l a2, -(sp)
    bsr     loadUnload
    cmp.l   #0, d2
    beq     .error
    movem.l (sp)+, a2
    
    
    jsr    TestDraw
    movem.l d1-d6/a1,-(sp)
    * Start testing draw
    lea     FILEBUFFER, a1 
    clr.l   d1
    
    move.l  #150, d1    // draw x
    move.l  #150, d2    // draw y
    move.l  #5, d3    // rect start point x
    move.l  #70, d4    // rect start point y
    move.l  #65, d5     // rect x
    move.l  #65, d6    // rect y
    * Test draw pos y is smaller than rect y, should return err
    *move.l  #450, d6
    *bsr     bmp_draw
    *cmp     #1, d0
    *bne     .error
    *move.l  #500, d6
    
    * Test rect height is bigger than start y + 1, should return err
    *move.l  #602, d2
    *bsr     bmp_draw
    *cmp     #1, d0
    *bne     .error
    *move.l  #500, d2
    
    * Test rect width + start.x is bigger than image width
    *move.l  #701, d1
    *bsr     bmp_draw
    *cmp     #1, d0
    *bne     .error
    *move.l  #550, d1
    
    
    * this will render a tifa head if using test1 (32 bit) 
    * Uncomment below to render a bigger picture, change output window also
    *move.l  #50, d1    // draw x
    *move.l  #900, d2    // draw y
    *move.l  #100, d3    // rect start point x
    *move.l  #900, d4    // rect start point y
    *move.l  #800, d5     // rect width
    *move.l  #800, d6    // rect height
    bsr     bmp_draw
    cmp     #0, d0
    bne     .error
    
    movem.l (sp)+,d1-d6/a1
    
    * check if registers are successfully restored
    bsr     CheckRegs
    tst.b   d0
    bne     .error

    
    bra     .done
    
    
.error
    moveq   #TASK_PRINT, d0
    lea     ErrorLabel, a1
    trap    #15

.done
    SIMHALT             ; halt simulator

* Call switchEndian with even number of bytes
switchEndianTestEven:
    move.l  #$01020304, d0
    move.l  #4, d1
    bsr     switchEndian
    
    cmp.l   #$04030201, d0
    bne     .error
    clr.l   d1
    clr.l   d0
    rts
    
.error
    move.l  d0, 1
    rts

* Call switchEndian with odd number of bytes
switchEndianTestOdd:
    move.l  #$010203, d0
    move.l  #3, d1
    bsr     switchEndian
    
    cmp.l   #$03020100, d0
    bne     .error
    clr.l   d1
    clr.l   d0
    rts
.error
    move.l  d0, 1
    rts

* Call bmp_load then bmp_unload, check output.bmp and d0 return
loadUnload:
    lea     INPUT_FILE, a1
    lea     FILEBUFFER, a2
    move.l  #FILESIZE,d1
    bsr     bmp_load
    cmp.b   #0, d0
    bne     .error
    
    *lea     OUTPUT_FILE, a1
    *lea     FILEBUFFER, a2
    *move.l  #FILESIZE,d1
    *bsr     bmp_unload
    *cmp.b   #0, d0
    *bne     .error
    *rts
    
.error
    move.b  #1, d0  
    rts
    
loadUnload2:
    lea     INPUT_FILE2, a1
    lea     FILEBUFFER2, a2
    move.l  #FILESIZE,d1
    bsr     bmp_load
    cmp.b   #0, d0
    bne     .error
    
    lea     OUTPUT_FILE2, a1
    lea     FILEBUFFER2, a2
    move.l  #FILESIZE,d1
    bsr     bmp_unload
    cmp.b   #0, d0
    bne     .error
    rts
    
.error
    move.b  #1, d0  
    rts


TestCheckCollision:
    movem.l All_REG, -(sp)
    move.w  #200, d0
    move.w  #200, d1
    move.w  #50, d2
    move.w  #200, d3
    jsr     checkCollisionWithPlayer
    cmp.l   #1, d4
    bne     .error
    movem.l (sp)+, ALL_REG
    
    movem.l All_REG, -(sp)
    move.w  #201, d0
    move.w  #200, d1
    move.w  #50, d2
    move.w  #200, d3
    jsr     checkCollisionWithPlayer
    cmp.l   #1, d4
    bne     .error
    movem.l (sp)+, ALL_REG
    
    movem.l All_REG, -(sp)
    move.w  #50, d0
    move.w  #200, d1
    move.w  #201, d2
    move.w  #200, d3
    jsr     checkCollisionWithPlayer
    cmp.l   #2, d4
    bne     .error
    movem.l (sp)+, ALL_REG
    
    movem.l All_REG, -(sp)
    move.w  #200, d0
    move.w  #200, d1
    move.w  #200, d2
    move.w  #200, d3
    jsr     checkCollisionWithPlayer
    cmp.l   #3, d4
    bne     .error
    movem.l (sp)+, ALL_REG
    
    rts


TestDraw
    movem.l d1-d6/a1,-(sp)
    * Start testing draw
    lea     FILEBUFFER, a1 
    clr.l   d1
    
    move.l  #150, d1    // draw x
    move.l  #150, d2    // draw y
    move.l  #5, d3    // rect start point x
    move.l  #70, d4    // rect start point y
    move.l  #65, d5     // rect x
    move.l  #65, d6    // rect y
    
    bsr     bmp_draw
    cmp     #0, d0
    bne     .error
    
    movem.l (sp)+,d1-d6/a1
    
    rts


*---
FillRegs:
    ;move.l  #SENTINEL, d0
    ;move.l  #SENTINEL, d1
    move.l  #SENTINEL, d2
    move.l  #SENTINEL, d3
    move.l  #SENTINEL, d4
    move.l  #SENTINEL, d5
    move.l  #SENTINEL, d6
    move.l  #SENTINEL, d7
    ;move.l  #SENTINEL, a0
    ;move.l  #SENTINEL, a1
    move.l  #SENTINEL, a2
    move.l  #SENTINEL, a3
    move.l  #SENTINEL, a4
    move.l  #SENTINEL, a5
    move.l  #SENTINEL, a6
    rts
    
*---
* out d0.b - 0 = success, non-zero = failure
*---
CheckRegs:
    move.b  #0, d0
    
    ;cmp.l   #SENTINEL, d0
    ;cmp.l   #SENTINEL, d1
    cmp.l   #SENTINEL, d2
    bne     .error
    cmp.l   #SENTINEL, d3
    bne     .error
    cmp.l   #SENTINEL, d4
    bne     .error
    cmp.l   #SENTINEL, d5
    bne     .error
    cmp.l   #SENTINEL, d6
    bne     .error
    cmp.l   #SENTINEL, d7
    bne     .error
    ;cmp.l   #SENTINEL, a0
    ;cmp.l   #SENTINEL, a1
    cmp.l   #SENTINEL, a2
    bne     .error
    cmp.l   #SENTINEL, a3
    bne     .error
    cmp.l   #SENTINEL, a4
    bne     .error
    cmp.l   #SENTINEL, a5
    bne     .error
    cmp.l   #SENTINEL, a6
    beq     .done

.error
    move.b  #1, d0
.done
    rts


* Put variables and constants here
INPUT_FILE    dc.b  'PlayerWizard.bmp', 0
INPUT_FILE2   dc.b  'test1.bmp', 0     
OUTPUT_FILE   dc.b  'output1.bmp', 0
OUTPUT_FILE2   dc.b  'output2.bmp', 0
ErrorLabel      dc.b    'An error was encountered',0

FILESIZE    EQU     $400038
            ds.l    0
FILEBUFFER  ds.b    FILESIZE
            ds.l    0
FILEBUFFER2 ds.b    FILESIZE
    END    START        ; last line of source

























*~Font name~Fixedsys~
*~Font size~9~
*~Tab type~1~
*~Tab size~4~
