*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
File_TASK_PRINT      EQU     13
FILE_TASK_FOPEN      EQU     51
FILE_TASK_FCREATE    EQU     52
FILE_TASK_FREAD      EQU     53
FILE_TASK_FWRITE     EQU     54
FILE_TASK_FCLOSE     EQU     56
IMAGE_FORMAT_OFFSET  EQU     0
SIZE_OFFSET          EQU     2
COLOR_FORMAT_OFFSET  EQU     28
WIDTH_OFFSET         EQU     18
HEIGHT_OFFSET        EQU     22
IMAGE_OFFSET         EQU     54
SET_PEN_COLOR_CMD    EQU     80
DRAW_PIXEL_CMD       EQU     82
ALL_REG                 REG     d0-d7/a0-a6 



*---
* Write a buffer to a file
*
* a1 - start address of filename
* a2 - start address of buffer to write
* d1.l - size of buffer to write
*
* out d0.b - 0 for success, non-zero for failure
*---
bmp_unload:
        movem.l    d1-d2/a1, -(sp)
        move.l      a2, a3
        *Compute pixel numbers
        move.l      WIDTH_OFFSET(a3),d0
        bsr         switchEndian
        move.l      d0, d2
        move.l      HEIGHT_OFFSET(a3),d0
        bsr         switchEndian
        mulu        d0, d2     // d1 stores pixel numbers
.fileConvert:
        *convert all image pixel to 68k format
        move.l      IMAGE_OFFSET(a3),d0
        rol.l       #8, d0
        move.l      d0, IMAGE_OFFSET(a3)
        add.l       #4, a3
        sub.l       #1, d2
        cmp.l       #0, d2
        bne         .fileConvert

.afterConvert       
        * d0 used for filewrite cmd
        * a1 for output filename 
        * d2 is used to store size to write
        move.l     d1, d2
        move.b     #FILE_TASK_FCREATE, d0
        trap #15
        cmp.b      #0, d0
        bne       .error
        * After read d1 stores filename
        move.b     #FILE_TASK_FWRITE,d0
        move.l     a2, a1
        
        trap #15
        cmp.b      #0, d0
        bne        .error
        
        * Close file
        move.b     #FILE_TASK_FCLOSE,d0
        trap #15
        cmp        #0, d0
        bne        .error
        
        movem.l    (sp)+, d1-d2/a1
        rts

.error
    move.b      #1,d0
    rts


*---
* Read a buffer from a file
*
* a1 - start address of filename
* a2 - start address of buffer to read
* d1.l - size of buffer to read
*
* out d1.l - number of bytes read
* out d0.b - 0 for success, non-zero for failure
*---
bmp_load:
        * a1 is opening file name
        *move.l      (a1),d3         //copy file name in d3
        movem.l    d2-d3/a1, -(sp)
        move.l     d1, d2
        move.b     #FILE_TASK_FOPEN, d0
        trap #15
        cmp.b      #0, d0
        bne       .error
        
        move.l      d1,d3 
        * file name stored in d1
        * d2.l num of bytes to read for FILE_READ        
        * a1 is buffer to read
        * output d1.l as size read
        move.b     #FILE_TASK_FREAD,d0
        move.l     a2, a1
        
        trap #15
        cmp.b      #0, d0
        bne        .error
        
        *check width < 1024
        move.l      WIDTH_OFFSET(a2),d0
        move.l      #4, d1
        bsr         switchEndian
        cmp.l      #1024, d0
        bhi        .error
        *check height < 1024
        move.l      HEIGHT_OFFSET(a2),d0
        bsr         switchEndian
        cmp.l      #1024, d0
        bhi         .error
        *check bmp format is 24 or 32
        clr.l       d0
        move.l      COLOR_FORMAT_OFFSET(a2),d0
        move.l      #2, d1
        bsr         switchEndian
        cmp.w       #24, d0          // check 24
        bne         .check32         // if not 24, check 32
        move.w      #3, bitsPerPixel // if 24, assign bitsPerPixel
        bra         .afterCheck
* check is 32 bit color format
.check32:
        clr.l       d0
        move.l      COLOR_FORMAT_OFFSET(a2),d0
        bsr         switchEndian
        cmp.w       #32, d0
        bne         .error   
        move.w      #4, bitsPerPixel
        *Compute pixel numbers
        move.l      WIDTH_OFFSET(a2),d0
        bsr         switchEndian
        move.l      d0, d1  //weight
        move.l      HEIGHT_OFFSET(a2),d0
        bsr         switchEndian    //height
        mulu        d0, d1      // d1 stores pixel numbers
.fileConvert:
        *convert all image pixel to 68k format
        move.l      IMAGE_OFFSET(a2),d0
        ror.l       #8, d0
        move.l      d0, IMAGE_OFFSET(a2)
        add.l       #4, a2
        sub.l       #1, d1
        cmp.l       #0, d1
        bne         .fileConvert
.afterCheck
        move        d3, d1 // restore file name
        * Close file
        move.b     #FILE_TASK_FCLOSE,d0
        trap #15
        cmp        #0, d0
        bne        .error
        
        move.l     d2, d1
        movem.l    (sp)+,d2-d3/a1
        rts

.error
    move.b      #1,d0
    rts
    
* switch from little endian to big endian
* d0.l is the data content
*
* out d0 is switched data
switchEndian:
    * d5 is temp storage for d2
    ror.w       #8, d0     ; Rotate the lower word to swap the lowest bytes
    swap        d0         ; Swap the upper and lower 16-bit words
    ror.w       #8, d0     ; Rotate the lower word to swap the previously upper bytes
    rts

* Draw rect from picture
* Start position is lower left corner
* a1 is loaded picture address
* d1 is draw x
* d2 is draw y
* d3 is rect starting point x
* d4 is rect starting point y
* d5 is rect width
* d6 is rect height
*
* out d0 - 0 for success, 1 for failure 
bmp_draw
    movem.l      ALL_REG, -(sp)
    * Assign drawposition x and y and load bitsPerPixel to a3
     lea         bitsPerPixel, a3   
     move.w       d1, drawPositionX
     move.w       d2, drawPositionY 
     
     * check rect y is in bound
     move.l      a1, a2
     move.l      d4, d0
     addq        #1, d0
     cmp.l       d0, d6   
     bgt         .error     // if rect.y is bigger than start.y index + 1, err
     
     * check rect x is in bound
     move.l      d3, d0
     add.l       d5, d0
     move.l      WIDTH_OFFSET(a1),d7
     ror.w       #8, d7     ; Rotate the lower word to swap the lowest bytes
     swap        d7         ; Swap the upper and lower 16-bit words
     ror.w       #8, d7 
     cmp.l       d7,d0
     bgt         .error   // if d3+d5 bigger than width, err
     
     * Check draw position is low enough to contain picture
     cmp.l       d2, d6
     bgt         .error       // if rect.y is bigger than draw pos.y, err
     
     * Store offset between rect.y and image height
     move.l      HEIGHT_OFFSET(a1),d0
     bsr         switchEndian    
     sub.l       d4, d0
    
     add.l       #IMAGE_OFFSET, a2 // now a2 represent pixel data start
     
     * Start locating start point
     * locate row
     move.l      WIDTH_OFFSET(a1),d7
     ror.w       #8, d7
     swap        d7         
     ror.w       #8, d7 
     
     mulu        (a3),d7           // every pixel is 3 bits, with Width num of pixels
* For 32 bit color format, compute bits per row
     move.l      d7, d4         // copy d7 to d4. d4 is number of bits per row       
     mulu        d0, d7
     add.l       d7, a2
     
     * locate column
     mulu        (a3),d3
     add.l       d3, a2         // now a2 is starting point address
     move.l      a2, d3         // d3 is now the address of starting point
     * start loop
.outerLoop
    *check row d2 is 0
    cmp.l       #0, d6
    beq         .return
    movem.l      d5, -(sp)     
.innerLoop
    * start printing
    * check if d3 is 0
    cmp.l       #0, d5
    beq         .nextRow
    
* For 32 bit color format
* Store color in d0 then update a2 to next pixel
    move.l      (a2),d0
    add.l        #4,a2     // update a2
    
    *check if is background
    cmp.l       #$00000002, d0
    beq         .updateCounter
    cmp.l       #$00000000, d0
    beq         .updateCounter
    * start to print pixel
    move.l      d1, d7      // temp store d1 at d7
    move.l      d0, d1      // store pen color in d1
    move.l      #SET_PEN_COLOR_CMD, d0
    trap        #15
    
    move.l      d7, d1      // restore d1 draw x
    move.l      #DRAW_PIXEL_CMD, d0
    trap        #15

.updateCounter
    * update d2, a2 counter and print next in row
    sub.l        #1, d5
    add.l        #1, d1 
    bra         .innerLoop
    
.nextRow
    * Update counters
    movem.l     (sp)+, d5
    sub.l       #1, d6
    lea         drawPositionX, a4
    move.w      (a4),d1      // draw pos x restored init pos
    sub.l       #1, d2       // draw pos y increment by 1 

    * Update a2 to next row start point
    add.l       d4, d3
    move.l      d3, a2  
    
    bra         .outerLoop
    
.return 
    movem.l     (sp)+, ALL_REG
    move.l      #0, d0
    rts   
    
.error
    movem.l     (sp)+, ALL_REG
    move.l      #1,d0
    rts
    
    
bitsPerPixel    ds.w    1
drawPositionX   ds.w    1
drawPositionY   ds.w    1
















*~Font name~Fixedsys~
*~Font size~9~
*~Tab type~1~
*~Tab size~4~
