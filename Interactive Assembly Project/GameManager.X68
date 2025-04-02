 *-----------------------------------------------------------
* Title      : Slime Smasher
* Written by : Julian Cai
* Date       : 
* Description: This is a game of a wizard fighting slimes. Press space to throw 
*              your staff. WASD to move and don't let the slime hit you!
*-----------------------------------------------------------
       
    ORG    $1000 ; first instruction of program
    INCLUDE 'bitmap.X68'
*all registers
ALL_REG                 REG     d0-d7/a0-a6    

*trap
CLEAR_SCREEN_COMMAND    equ     11
TASK_PRINT              equ     13
DOUBLE_BUFFERED_MODE	equ	    17
GET_USER_INPUT_COMMAND  equ     19
DRAWING_MODE_TRAP_CODE	equ	    92
REPAINT_SCREEN_TRAP_CODE	equ	94
SET_PEN_COLOR_COMMAND   equ     80
SET_FILL_COLOR_COMMAND  equ     81
DRAW_RECTANGLE_COMMAND  equ     87
DRAW_CIRCLE_COMMAND     equ     88
DELAY_FRAME	            equ	    23
DOUBLE_BUFFERED_OFF     equ     16
LOAD_SOUND_COMMAND      equ     71
PLAY_SOUND_COMMAND      equ     72

*key code
KEY_LEFT_INPUT          equ     $25
KEY_UP_INPUT            equ     $26
KEY_RIGHT_INPUT         equ     $27
KEY_DOWN_INPUT          equ     $28

KEY_SPACE_INPUT         equ     $20
KEY_W_INPUT             equ     $57
KEY_A_INPUT             equ     $41
KEY_S_INPUT             equ     $53
KEY_D_INPUT             equ     $44


*self-defined constant
PLAYER_MOVE_DIST        equ     25
CLEAR_SCREEN_MAGIC_VAL  equ     $FF00
FRAME_DELAY_TIME        EQU     50
PLAYER_WIDTH            EQU     40
PLAYER_HEIGHT           EQU     65
PROJECTILE_X_OFFSET     EQU     20
PROJECTILE_ACC          EQU     6
PROJECTILE_INIT_SPEED   EQU     45
PROJECTILE_HEIGHT       EQU     55
ENEMY_WIDTH             EQU     38
ENEMY_HEIGHT            EQU     20
ENEMY_DMG               EQU     10
BITMASK                 EQU     $00000001
STAFF_FRAME_NUM         EQU     8
WIN_CONDITION           EQU     20
PROJECTILE_R_OFFSET     EQU     60
PROJECTILE_D_OFFSET     EQU     20
PROJECTILE_U_OFFSET     EQU     85

*color
BLACK   equ     $00000000
RED     equ     $000000FF
GREEN   equ     $0000FF00
BLUE    equ     $00FF0000
YELLOW  equ     RED+GREEN
ORANGE  equ     $003090FF
WHITE   equ     RED+GREEN+BLUE

*7SEG
ZERO    EQU     $01111110
ONE     EQU     $00110000
TWO     EQU     $01101101
THREE   EQU     $01111001
FOUR    EQU     $00110011
FIVE    EQU     $01011011
SIX     EQU     $01011111                                                                                   
SEVEN   EQU     $01110000
EIGHT   EQU     $01111111
NINE    EQU     $01111011


*power meter info
POWER_METER_TOP                 equ     15
POWER_METER_BOTTOM              equ     30
POWER_METER_LEFT                equ     40
POWER_METER_RIGHT               equ     250
POWER_METER_COLOR               equ     BLUE
POWER_METER_INSIDE_COLOR        equ     RED
POWER_METER_SPEED               equ     256




START:
    *jsr     RunTest
*set double buffered mode
    move.l  #DRAWING_MODE_TRAP_CODE,d0
    move.l  #DOUBLE_BUFFERED_MODE,d1
    trap    #15
*init projectile
    bsr     loadStaff
    move.w  #0, projectileActive
    move.w  #0, projectileThrown
    move.w  #PROJECTILE_INIT_SPEED, projectile_Speed
*init player position
    move.w  #250, PLAYER_X    // draw x
    move.w  #250, PLAYER_Y    // draw y
*init enemies pos
    lea     ENEMY_POS, a0
    move.l  #ENEMY_NUM, d2
    lea     ENEMY_ACTIVE, a2
    lea     ENEMY_MOVE_DIST, a3
    move.l  #50, d3
    move.l  #400, d4
* init enemies hit count
    move.w  #0, enemy_hit
*init enemy speed random seed
    move.l  #$ABF2, Prng32
*init player frames
    move.w  #0, playerL_frame
    move.w  #0, playerR_frame
    move.w  #0, attack_frame
    move.w  #0, player_facing
    move.w  #0, is_attacking
*init health bar
    move.l  #100, powerMeterPercent 
*init all sound
    lea     SOUND_FILE, a1
    move.l  #LOAD_SOUND_COMMAND, d0
    move.l  #1, d1
    trap    #15
    lea     SOUND_FILE1, a1
    move.l  #2, d1
    trap    #15
    lea     SOUND_FILE2, a1
    move.l  #3, d1
    trap    #15
    lea     SOUND_FILE3, a1
    move.l  #4, d1
    trap    #15
* Init enemy active state to inactive
.loop
    * a2 isActive, a0 enemy pos, a3 enemy speed 
    cmp.l   #0, d2
    beq     .continue
    move.b  #00, (a2)   // set to inactive
    *Update counters
    add.l   #1, a2  //enemy counter
    sub.l   #1, d2      // loop counter
    bra     .loop
.continue
*load player and enemy asset
    bsr     loadPlayer
    cmp.l   #1, d0
    beq     .error

    bsr     loadEnemy
    cmp.l   #1, d0
    beq     .error
*load win lose asset 
    bsr     loadWin
    cmp.l   #1, d0
    beq     .error

    bsr     loadLose
    cmp.l   #1, d0
    beq     .error

* game loop start
    bra     gameLoop
.error
    move.l  d0, 1
    rts

* this is a run test subroutine
RunTest
    * unit test for check collision with player, used in debug phase
    jsr     TestCheckCollision
    rts    
    
* The game loop
gameLoop:
*read the input
    jsr	    clearScreen
*Handle input  
    bsr     drawHealthBar
    jsr     handleInput
    bsr     drawPlayer
*Update and draw projectile
    bsr     drawStaff
    jsr     updateStaff
*Update Enemy before draw
    jsr     EnemySpawn   
    bsr     drawAllEnemies
    
*Update UI
    jsr     updateUI
*Swap buffers
    jsr	    swapBuffers
*Check Win
    cmp.w   #WIN_CONDITION, enemy_hit
    bge     Win  
*Check Lose
    cmp.l   #0, powerMeterPercent
    ble     Lose
*game updates
    bra     gameloop

loadPlayer:
    lea     INPUT_FILE, a1
    lea     FILEBUFFER, a2
    move.l  #FILESIZE,d1
    bsr     bmp_load
    cmp.b   #0, d0
    bne     .error
    
    lea     INPUT_FILE5, a1
    lea     FILEBUFFER5, a2
    move.l  #FILESIZE,d1
    bsr     bmp_load
    cmp.b   #0, d0
    bne     .error
    
    lea     INPUT_FILE6, a1
    lea     FILEBUFFER6, a2
    move.l  #FILESIZE,d1
    bsr     bmp_load
    cmp.b   #0, d0
    bne     .error
    
    lea     INPUT_FILE7, a1
    lea     FILEBUFFER7, a2
    move.l  #FILESIZE,d1
    bsr     bmp_load
    cmp.b   #0, d0
    bne     .error
    rts


.error
    move.l  d0, 1
    rts
    
loadEnemy
    lea     INPUT_FILE1, a1
    lea     FILEBUFFER1, a2
    move.l  #FILESIZE1,d1
    bsr     bmp_load
    cmp.b   #0, d0
    bne     .error
    rts
.error
    move.l  d0, 1
    rts
    
loadStaff
    lea     INPUT_FILE2, a1
    lea     FILEBUFFER2, a2
    move.l  #FILESIZE2,d1
    bsr     bmp_load
    cmp.b   #0, d0
    bne     .error
    rts
.error
    move.l  d0, 1
    rts

loadWin
    lea     INPUT_FILE3, a1
    lea     FILEBUFFER3, a2
    move.l  #FILESIZE3,d1
    bsr     bmp_load
    cmp.b   #0, d0
    bne     .error
    rts
.error
    move.l  d0, 1
    rts

loadLose
    lea     INPUT_FILE4, a1
    lea     FILEBUFFER4, a2
    move.l  #FILESIZE3,d1
    bsr     bmp_load
    cmp.b   #0, d0
    bne     .error
    rts
.error
    move.l  d0, 1
    rts
    
* clear whole screen
clearScreen
    move.b  #CLEAR_SCREEN_COMMAND,d0
    move.l  #CLEAR_SCREEN_MAGIC_VAL,d1
    TRAP    #15
	rts
* Player image is 74 * 80
* rect x is 40, y is 65
* rect start point [20, 70]
drawPlayer:
    clr.l    d1
    clr.l    d2     // clear d1d2, since later will move word into d1d2
    movem.l  d1-d3/a1-a3, -(sp)
    
    lea      PLAYER_X, a2
    lea      PLAYER_Y, a3
    
    move.w   (a2),d1
    move.w   (a3),d2
    
    cmp.w    #1, is_attacking
    beq      .attackDir
    *move.w   #1, player_facing
    cmp.w    #0, player_facing
    beq      .loadLeft
    bra      .loadRight
.attackDir
    cmp.w    #0, attack_dir
    beq      .attackL
    bra      .attackR
.attackR
    move.w  #1, attack_dir
    lea    FILEBUFFER6, a1
    lea    attackR_spriteFrames, a2
    lea    attack_frame, a3
    
    cmp.w   #5, attack_frame
    beq     .resetARFrame
    bra     .noARFreset
.resetARFrame
    move.w  #0, attack_frame
    move.w  #0, is_Attacking
    move.w  #1, projectileActive
    move.w  PLAYER_Y, PROJECTILE_Y                      
    move.w  PLAYER_X, PROJECTILE_X
    * update projectile
    add.w   #PROJECTILE_R_OFFSET, PROJECTILE_X
* in attack animation
.noARFreset
    move.w  attack_frame, d3
    mulu     #8, d3
    add.l    d3, a2
    move.w   (a2),d3
    move.w   2(a2),d4
    move.w   4(a2),d5
    move.w   6(a2),d6
    
    add.w   #1, attack_frame
    bra     .return
.attackL
    move.w  #0, attack_dir
    lea    FILEBUFFER7, a1
    lea    attackL_spriteFrames, a2
    lea    attack_frame, a3
    
    cmp.w   #5, attack_frame
    beq     .resetALFrame
    bra     .noALFreset
.resetALFrame
    move.w  #0, attack_frame
    move.w  #0, is_Attacking
    move.w  #1, projectileActive
    move.w  PLAYER_Y, PROJECTILE_Y                      
    move.w  PLAYER_X, PROJECTILE_X
    
    * update projectile
    sub.w   #PROJECTILE_X_OFFSET, PROJECTILE_X
* in attack animation
.noALFreset
    move.w  attack_frame, d3
    mulu     #8, d3
    add.l    d3, a2
    move.w   (a2),d3
    move.w   2(a2),d4
    move.w   4(a2),d5
    move.w   6(a2),d6
    
    add.w   #1, attack_frame
    bra     .return

* move left animation
.loadLeft      
    lea      FILEBUFFER, a1
    lea      playerL_spriteFrames, a2
    lea      playerL_frame, a3
    bra      .loaded
* move right animation
.loadRight  
    lea      FILEBUFFER5, a1
    lea      playerR_spriteFrames, a2
    lea      playerR_frame, a3
.loaded  
    * if frame reach last, reset to 0
    cmp.w    #staff_frame_num, (a3)
    beq      .resetFrame
    bra      .continue
.resetFrame
    move.w   #0, (a3)
.continue
    * set param for bmp_draw
    *move.w   #6, playerL_frame
    move.w   (a3),d3
    mulu     #8, d3
    add.l    d3, a2
    move.w   (a2),d3
    move.w   2(a2),d4
    move.w   4(a2),d5
    move.w   6(a2),d6
    *add.w    #1, playerL_frame
 
    *move.l   #0, d3
    *move.l   #70, d4
    *move.l   #70, d5
    *move.l   #65, d6
.return
    bsr      bmp_draw
    cmp      #0, d0
    bne      .error
    movem.l  (sp)+,d1-d3/a1-a3
    rts
.error
    moveq   #TASK_PRINT, d0
    lea     ErrorLabel, a1
    trap    #15
    movem.l  (sp)+,d1-d3/a1-a3
    rts


* this is the digit UI
drawUI:
    movem.l d1-d6, -(sp)
    *move.l  d0, d3
    move.l  d1, d5
    move.l  #RED,d1
    move.b  #SET_FILL_COLOR_COMMAND,d0
    TRAP    #15
    
    rol.l   #8, d5
    move.l  d5, d6
    and.l   #bitmask, d6
    cmp.l   #1, d6
    beq     .segA
    bra     .preSegB
.segA
    * Tenth Digit
    * seg A
    move.l  #450,d1
    move.l  #10,d2
    move.l  #480,d3
    move.l  #15,d4

    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.preSegB
    rol.l   #4, d5
    move.l  d5, d6 
    and.l   #bitmask, d6 
    cmp.l   #1, d6
    beq     .segB
    bra     .preSegC
.segB 
    * seg B
    move.l  #475,d1
    move.l  #17,d2
    move.l  #480,d3
    move.l  #37,d4

    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.preSegC
    rol.l   #4, d5
    move.l  d5, d6 
    and.l   #bitmask, d6
    cmp.l   #1, d6
    beq     .segC
    bra     .preSegD
.segC
    * draw seg C
    move.l  #475,d1
    move.l  #48,d2
    move.l  #480,d3
    move.l  #68,d4

    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.preSegD
    rol.l   #4, d5
    move.l  d5, d6 
    and.l   #bitmask, d6
    cmp.l   #1, d6
    beq     .segD
    bra     .preSegE
.segD
    * draw seg D
    move.l  #450,d1
    move.l  #71,d2
    move.l  #480,d3
    move.l  #76,d4

    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.preSegE
    rol.l   #4, d5
    move.l  d5, d6 
    and.l   #bitmask, d6
    cmp.l   #1, d6
    beq     .segE
    bra     .preSegF
.segE    
    * draw seg E
    move.l  #450,d1
    move.l  #48,d2
    move.l  #455,d3
    move.l  #68,d4
    
    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.preSegF    
    rol.l   #4, d5
    move.l  d5, d6 
    and.l   #bitmask, d6
    cmp.l   #1, d6
    beq     .segF
    bra     .preSegG
.segF
    * draw seg F
    move.l  #450,d1
    move.l  #17,d2
    move.l  #455,d3
    move.l  #37,d4
    
    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.preSegG
    rol.l   #4, d5
    move.l  d5, d6 
    and.l   #bitmask, d6
    cmp.l   #1, d6
    beq     .segG
    bra     .return
.segG
    * seg G
    move.l  #450,d1
    move.l  #40,d2
    move.l  #480,d3
    move.l  #45,d4


    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.return
    move.l  #0,d1
    move.b  #SET_FILL_COLOR_COMMAND,d0
    TRAP    #15

    movem.l (sp)+,d1-d6
    rts
    
* This is the tenth digit UI    
drawUITenth:
    movem.l d0-d6, -(sp)
    move.l  d0, d3
    move.l  d1, d5
    move.l  #RED,d1
    move.b  #SET_FILL_COLOR_COMMAND,d0
    TRAP    #15
    
    rol.l   #8, d5
    move.l  d5, d6
    and.l   #bitmask, d6
    cmp.l   #1, d6
    beq     .segA
    bra     .preSegB
.segA
    * Tenth Digit
    * seg A
    move.l  #400,d1
    move.l  #10,d2
    move.l  #430,d3
    move.l  #15,d4

    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.preSegB
    rol.l   #4, d5
    move.l  d5, d6 
    and.l   #bitmask, d6 
    cmp.l   #1, d6
    beq     .segB
    bra     .preSegC
.segB 
    * seg B
    move.l  #425,d1
    move.l  #17,d2
    move.l  #430,d3
    move.l  #37,d4

    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.preSegC
    rol.l   #4, d5
    move.l  d5, d6 
    and.l   #bitmask, d6
    cmp.l   #1, d6
    beq     .segC
    bra     .preSegD
.segC
    * seg C
    move.l  #425,d1
    move.l  #48,d2
    move.l  #430,d3
    move.l  #68,d4

    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.preSegD
    rol.l   #4, d5
    move.l  d5, d6 
    and.l   #bitmask, d6
    cmp.l   #1, d6
    beq     .segD
    bra     .preSegE
.segD
    * seg D
    move.l  #400,d1
    move.l  #71,d2
    move.l  #430,d3
    move.l  #76,d4

    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.preSegE
    rol.l   #4, d5
    move.l  d5, d6 
    and.l   #bitmask, d6
    cmp.l   #1, d6
    beq     .segE
    bra     .preSegF
.segE    
    * seg E
    move.l  #400,d1
    move.l  #48,d2
    move.l  #405,d3
    move.l  #68,d4
    
    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.preSegF    
    rol.l   #4, d5
    move.l  d5, d6 
    and.l   #bitmask, d6
    cmp.l   #1, d6
    beq     .segF
    bra     .preSegG
.segF
    * seg F
    move.l  #400,d1
    move.l  #17,d2
    move.l  #405,d3
    move.l  #37,d4
    
    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.preSegG
    rol.l   #4, d5
    move.l  d5, d6 
    and.l   #bitmask, d6
    cmp.l   #1, d6
    beq     .segG
    bra     .return
.segG
    * seg G
    move.l  #400,d1
    move.l  #40,d2
    move.l  #430,d3
    move.l  #45,d4


    move.b  #DRAW_RECTANGLE_COMMAND,d0
    TRAP    #15
.return
    move.l  #0,d1
    move.b  #SET_FILL_COLOR_COMMAND,d0
    TRAP    #15

    movem.l (sp)+,d0-d6
    rts

    
drawStaff:
    * check if projectile is active
    clr.l    d0
    clr.l    d1
    clr.l    d2     // clear d1d2, since later will move word into d1d2
    movem.l  d1-d3/a1-a2, -(sp)
    cmp.w   #0, projectileActive    
    beq     .return
    * when active, check current frame and get data to display
    lea      FILEBUFFER2, a1
    move.w   projectile_x,d1
    move.w   projectile_y,d2
    lea      staff_spriteFrames, a2
    * if frame reach last, reset to 0
    cmp.w    #staff_frame_num, staff_frame
    beq      .resetFrame
    bra      .continue
.resetFrame
    move.w   #0, staff_frame
.continue
    * set param for bmp_draw
    move.w   staff_frame, d3
    mulu     #8, d3
    add.l    d3, a2
    move.w   (a2),d3
    move.w   2(a2),d4
    move.w   4(a2),d5
    move.w   6(a2),d6
    add.w    #1, staff_frame
    bsr      bmp_draw
    cmp      #0, d0
    bne      .error
.return
    movem.l  (sp)+,d1-d3/a1-a2
    rts
.error
    moveq   #TASK_PRINT, d0
    lea     ErrorLabel, a1
    movem.l  (sp)+,d1-d3/a1-a2
    trap    #15


EnemySpawn:
    *d0 is enemy_num
    *d1 is enemyarray index
    *d2 is current enemy isActive bool
    *a1 is enemy_active array address
    *a2 is enemy_pos array address
    movem.l ALL_REG, -(sp) 
    move.l  #ENEMY_NUM, d0
    move.l  #0, d1
    lea     ENEMY_ACTIVE, a1
    lea     ENEMY_MOVE_DIST, a3
.loop
    cmp.b   d1, d0
    beq     .return
    * find inactive enemy and set it to active
    move.b  (a1),d2
    cmp.l   #0, d2
    beq     .setActive
    bra     .continueLoop
.setActive
    * Find cur enemy pos in enemy_pos array
    move.b  #1, (a1)
    lea     ENEMY_POS, a2
    mulu    #4, d1
    add.l   d1, a2
    divu    #4, d1
    
    * compute enemy x
    move.l  d1, d3
    mulu    #50, d3
    move.w  d3,(a2) // enemy x
    move.w  #600,2(a2)
    * set random speed for enemy
    jsr     random
    andi.l  #$0000000F, d0
    cmp.b   #0, d0
    beq     .increment
    bra     .postIncrement
.increment
    * if random return 0, set it to 3
    addq    #3, d0
.postIncrement
    move.b  d0, (a3)
    * after set one enemy, exit loop
    bra     .return
.continueLoop
    add.l   #1, d1
    add.l   #1, a1
    addq    #1, a3
    bra     .loop
.return
    movem.l (sp)+,ALL_REG
    rts

* delay frame api
delayFrame
    movem.l d1-d2, -(sp)
    move.l  #DELAY_FRAME, d0
    move.l  #FRAME_DELAY_TIME, d1
    TRAP    #15
    movem.l (sp)+, d1-d2
    rts
    
* DrawAllEnemies - Loop through enemy active, if byte is 01, draw the enemy
drawAllEnemies:
    movem.l ALL_REG, -(sp) 
    move.l  #ENEMY_NUM, d0
    move.l  #0, d1
    lea     ENEMY_ACTIVE, a1
    lea     ENEMY_POS, a2
    lea     ENEMY_MOVE_DIST, a3
    
.loop
    * loop through all enemy, return
    cmp.b   d1, d0
    beq     .return
    move.b  (a1),d2
    * enemy is active, draw enemy
    cmp.l   #1, d2
    beq     .drawUpdateIndex
    bra     .updateLoop
.drawUpdateIndex
    * set enemy speed and for update api
    move.b  (a3),d6
    * update and draw the enemy
    bsr     updateEachEnemy
    bsr     drawEnemy
.updateLoop
    * update loop counters
    add.b   #1, d1
    add.l   #1, a1
    add.l   #1, a3
    bra     .loop    
    
.return
    movem.l (sp)+,ALL_REG
    rts
    
* d1 is the index of the enemy
drawEnemy:
    movem.l  ALL_REG,-(sp)
    lea      FILEBUFFER1, a1
    * get current enemy pos from enemy_pos array
    lea     ENEMY_POS, a2
    mulu    #4, d1
    add.l   d1, a2
    move.w  (a2),d1
    move.w  2(a2),d2
    * set param for bmp_draw
    move.l   #5, d3
    move.l   #25, d4
    move.l   #ENEMY_WIDTH, d5
    move.l   #ENEMY_HEIGHT, d6
    
    bsr      bmp_draw
    cmp      #0, d0
    bne      .error
    movem.l  (sp)+,ALL_REG
    rts
.error
    moveq   #TASK_PRINT, d0
    lea     ErrorLabel, a1
    trap    #15
    rts

drawHealthBar
        movem.l ALL_REG,-(sp)
        move.l  #POWER_METER_COLOR,d1
        move.b  #SET_PEN_COLOR_COMMAND,d0
        TRAP    #15
        * draw health bar outside
        move.l  #POWER_METER_LEFT,d1
        move.l  #POWER_METER_TOP,d2
        move.l  #POWER_METER_RIGHT,d3
        move.l  #POWER_METER_BOTTOM,d4

        move.b  #DRAW_RECTANGLE_COMMAND,d0
        TRAP    #15
        
        * set inside health bar color
        move.l  d1,d7
        move.l  #POWER_METER_INSIDE_COLOR,d1
        move.b  #SET_FILL_COLOR_COMMAND,d0
        TRAP    #15
        * draw inside health bar
        move.l  d7,d1
        addi.l  #1,d1
        addi.l  #1,d2
        subi.l  #1,d4
        
        sub.l   #POWER_METER_LEFT, d3   
        lea     powerMeterPercent,a0
        move.l  (a0),d0

        mulu    d0, d3
        divu    #100, d3
        add.l   d1, d3
        
        move.b  #DRAW_RECTANGLE_COMMAND,d0
        TRAP    #15
        
        * reset fill color
        move.l  #0,d1
        move.b  #SET_FILL_COLOR_COMMAND,d0
        TRAP    #15

        movem.l (sp)+,ALL_REG
        rts     

* simple subroutine that swap buffers  
swapBuffers:
	move.b  #REPAINT_SCREEN_TRAP_CODE,d0
    TRAP    #15
	rts  

	
*check key codes, then call appropriate functions based on which key entered
handleInput:
    movem.l ALL_REG,-(sp)
    
    * Handle wasd movement key press
    *move.l  #(KEY_LEFT_INPUT<<24 + KEY_UP_INPUT<<16 + KEY_RIGHT_INPUT<<8 + KEY_DOWN_INPUT),d1
    move.l  #(KEY_A_INPUT<<24 + KEY_W_INPUT<<16 + KEY_D_INPUT<<8 + KEY_S_INPUT),d1
    move.b  #GET_USER_INPUT_COMMAND,d0
    TRAP    #15
    move.l  d1, d2
    andi.l  #$FF000000,d2
    bne     .keyLeftInput
    move.l  d1, d2
    andi.l  #$00FF0000,d2
    bne     .keyUpInput
    move.l  d1, d2
    andi.l  #$0000FF00,d2
    bne     .keyRightInput
    move.l  d1, d2
    andi.l  #$000000FF,d2
    bne     .keyDownInput
    
    * Handle left right space attack key press
    move.l  #(KEY_LEFT_INPUT<<16 + KEY_RIGHT_INPUT<<8 + KEY_SPACE_INPUT),d1
    move.b  #GET_USER_INPUT_COMMAND,d0
    TRAP    #15
    move.l  d1, d2
    andi.l  #$00FF0000,d2
    bne     .AttackLeftInput
    move.l  d1, d2
    andi.l  #$0000FF00,d2
    bne     .AttackRightInput
    move.l  d1, d2
    andi.l  #$000000FF,d2
    bne     .ThrowStaffInput
        
    bra     .doneInput 
.keyLeftInput
    *player moveLeft boundary check
    move.w  PLAYER_X, d0
    sub.w   #PLAYER_MOVE_DIST, d0
    cmp.l   #0, d0
    ble     .doneInput
    * move left
    sub.w   #PLAYER_MOVE_DIST, PLAYER_X
    add.w   #1, playerL_frame
    move.w  #0, player_facing
    bsr     drawPlayer
    bra     .doneInput
    
.keyUpInput
    * player move up boundary check
    move.w  PLAYER_Y, d0
    sub.w   #PLAYER_MOVE_DIST, d0
    cmp.l   #PLAYER_HEIGHT, d0
    ble     .doneInput
    * Move up
    sub.w   #PLAYER_MOVE_DIST, PLAYER_Y
    * set player frame for walking left or right
    cmp.w   #0, player_facing
    beq     .incLeft
    bra     .incRight
.incLeft
    add.w   #1, playerL_frame
    bra     .inced
.incRight
    add.w   #1, playerR_frame
.inced
    bsr     drawPlayer
    bra     .doneInput
    
.keyRightInput
    * player moveRight boundary check
    move.w  PLAYER_X, d0
    add.w   #PLAYER_MOVE_DIST, d0
    add.w   #PLAYER_WIDTH,d0
    cmp.l   #640, d0
    bge     .doneInput
    * Move right
    add.w   #PLAYER_MOVE_DIST, PLAYER_X
    add.w   #1, playerR_frame
    move.w  #1, player_facing
    bsr     drawPlayer
    bra     .doneInput
    
.keyDownInput
    * player moveDown boundary check
    move.w  PLAYER_Y, d0
    add.w   #PLAYER_MOVE_DIST, d0
    cmp.l   #480, d0
    bge     .doneInput
    * Move down
    add.w   #PLAYER_MOVE_DIST, PLAYER_Y
    * set player frame for walking left or right
    cmp.w   #0, player_facing
    beq     .incLeft
    bra     .incRight
.incLeft1
    add.w   #1, playerL_frame
    bra     .inced
.incRight1
    add.w   #1, playerR_frame
.inced1
    bsr     drawPlayer
    bra     .doneInput
* this is not implemented    
.AttackLeftInput
    *moveq   #TASK_PRINT, d0
    *lea     DebugLabel, a1
    *trap    #15
    *bra     .doneInput
* this is not implemented 
.AttackRightInput
    *moveq   #TASK_PRINT, d0
    *lea     DebugLabel, a1
    *trap    #15
    *bra     .doneInput
* space!
.ThrowStaffInput
    * if projectile is thrown, cannot throw again
    cmp.w   #1, projectileThrown
    beq     .doneInput
    
    * set projectile to active for drawing
    move.w  #0, staff_frame                             ; init staff_frame
    move.w  #1, is_attacking                            ; init attack animation
    move.w  #0, attack_frame
    move.w  player_facing, attack_dir                   ; set playerfacing as attack direction
    *move.w  #1, projectileActive                        ; set projectile as active
    move.w  #PROJECTILE_INIT_SPEED, projectile_speed    ; set projectile init speed
    move.w  #1, projectileThrown                        ; set projectile as thrown
    * init projectile init pos
    *move.w  PLAYER_Y, PROJECTILE_Y                      
    *move.w  PLAYER_X, PROJECTILE_X
    
    *cmp.w   #0, player_dir
    *beq     .playerLeft
    
    *cmp.w   #1, player_dir
    *beq     .playerRight
    
    *cmp.w   #2, player_dir
    *beq     .playerUp
    
    *cmp.w   #3, player_dir
    *beq     .playerDown
    
.playerLeft
    sub.w   #PROJECTILE_X_OFFSET, PROJECTILE_X
    bra     .doneInput
.playerRight
    add.w   #PROJECTILE_R_OFFSET, PROJECTILE_X
    bra     .doneInput
* not used
.playerUp
    add.w   #PROJECTILE_D_OFFSET, PROJECTILE_X
    sub.w   #PROJECTILE_U_OFFSET, PROJECTILE_Y
    bra     .doneInput
* not used
.playerDown
    add.w   #PROJECTILE_D_OFFSET, PROJECTILE_X
    add.w   #PROJECTILE_X_OFFSET, PROJECTILE_Y
.doneInput
    movem.l (sp)+,ALL_REG
        
    rts
    
* Enemy moves at a fixed rate towards player
* d1 is the index of the enemy
* d6 is enemy speed
updateEachEnemy:
    movem.l ALL_REG,-(sp)
    move.l  d1, d7  // this is enemy index
    
    * get enemy position for this instance
    lea     ENEMY_POS, a2
    mulu    #4, d1
    add.l   d1, a2
    move.w  (a2),d0 // enemy x
    move.w  2(a2),d2 // enemy y
    
    * check collision with projectile
    move.w  projectile_x, d1
    move.w  projectile_y, d3
    bsr     checkProjectileCol
    
    cmp.l   #1, d4
    beq     .die
    bra     .live
* collided with projecile
.die
    * play player hit sound
    move.l  #PLAY_SOUND_COMMAND, d0
    move.l  #1, d1
    trap    #15
    * set enemy active to false
    lea     ENEMY_ACTIVE, a4
    add.l   d7, a4
    move.b  #0, (a4)
    * increment enemy hit counter
    add.w   #1, enemy_hit
    bra     .return
.live
    * not collided the check player collision
    lea     PLAYER_X, a1
    move.w  (a1),d1
    lea     PLAYER_Y, a3
    move.w  (a3),d3 
    bsr     checkCollisionWithPlayer
    
    cmp.b   #3, d4  // if collide with player, attack
    beq     .enemyAttack    
    bra     .enemyNotAttack
.enemyAttack
    * play attack sound
    move.l  #PLAY_SOUND_COMMAND, d0
    move.l  #2, d1
    trap    #15
    * set enemy active as false
    lea     ENEMY_ACTIVE, a4
    add.l   d7, a4
    move.b  #0, (a4)
    * reduce player health
    lea     powerMeterPercent, a5
    move.l  (a5),d5
    sub.l   #ENEMY_DMG, d5
    move.l  d5, powerMeterPercent
    bra     .return
    
.enemyNotAttack
    cmp.b   #1, d4          ; if x collide, enemy don't move on x axis
    beq     .checkUpDown    ; check if y collide
    
    cmp.l   d0, d1          ; if playerX is bigger than enemy x
    bgt     .moveRight
    bra     .moveLeft

.moveRight
    add.w   d6, (a2)
    bra     .checkUpDown
.moveLeft
    sub.w   d6, (a2)
.checkUpDown
    cmp.b   #2, d4          ; if y collide, dont move on y, return
    beq      .return
    cmp.l   d2, d3          ; if playerY is bigger than enemy Y, move down
    bgt     .moveDown       
    bra     .moveUp
.moveDown
    add.w   d6, 2(a2)
    bra     .return
.moveUp
    sub.w   d6, 2(a2)
    
.return
    movem.l (sp)+,ALL_REG
    rts

updateStaff:
    movem.l ALL_REG,-(sp)
    cmp.w   #0, projectileActive
    beq     .return
    
    *PROJECTILE_SPEED        EQU     10
    *PROJECTILE_ACC          EQU     3
    * check speed is positive or neg
    sub.w   #projectile_acc, projectile_speed
    cmp.w   #0, projectile_speed
    ble     .tracingtoPlayer
    
    cmp.w   #0, attack_dir
    beq     .travelLeft
    
    cmp.w   #1, attack_dir
    beq     .travelRight
    
    *cmp.w   #2, player_dir
    *beq     .travelUp
    
    *cmp.w   #3, player_dir
    *beq     .travelDown
    
.travelLeft
    * start traveling with x speed
    move.w  projectile_speed, d0
    * if projectile will throw off left bound, handle edge case
    cmp.l   projectile_x, d1
    bgt     .boundaryCase
    sub.w   d0, projectile_x
    bra     .return
.boundaryCase
    move.w  #0, projectile_x
    move.w  #0, projectile_speed
    bra     .return
.travelRight
    * start traveling with x speed
    move.w  projectile_speed, d0
    add.w   d0, projectile_x
    bra     .return
* not used
.travelUp
    * start traveling with x speed
    move.w  projectile_speed, d0
    * if projectile will throw off left bound, handle edge case
    *cmp.l   projectile_x, d1
    *bgt     .boundaryCase
    sub.w   d0, projectile_y
    bra     .return
* not used
.travelDown
    * start traveling with x speed
    move.w  projectile_speed, d0
    * if projectile will throw off left bound, handle edge case
    *cmp.l   projectile_x, d1
    *bgt     .boundaryCase
    add.w   d0, projectile_y
    bra     .return
.tracingtoPlayer
    * start flying back to player
    * set param for checkCollision api
    move.w  projectile_x, d0
    move.w  player_x, d1
    move.w  projectile_y, d2
    move.w  player_y, d3
    move.w  projectile_speed, d6
    * convert projectile_speed to pos
    not.w   d6              ; Invert the bits (D0 = ~D0)
    add.w   #1, d6
    * if api return 3, collided
    jsr     checkCollisionWithPlayer
    cmp.b   #3, d4
    beq     .backToPlayer
    bra     .stillInMotion
.backToPlayer
    move.w  #0, projectileThrown
    move.w  #0, projectileActive
    bra     .return
* determine flight path based on collision api return val
.stillInMotion
    cmp.b   #1, d4      // if x collide
    beq     .checkUpDown
    
    cmp.l   d0, d1  // if playerX is bigger than enemy x
    bgt     .moveRight
    bra     .moveLeft

.moveRight
    add.w   d6, projectile_x
    bra     .checkUpDown
.moveLeft
    sub.w   d6, projectile_x
.checkUpDown
    cmp.b   #2, d4      // if y collide
    beq      .return
    cmp.l   d2, d3  // if playerY is bigger than enemy Y
    bgt     .moveDown
    bra     .moveUp
.moveDown
    add.w   d6, projectile_y
    bra     .return
.moveUp
    sub.w   d6, projectile_y

.return
    movem.l (sp)+,ALL_REG
    rts
    
* Update ui to show how many enemy player have hit
updateUI:
    movem.l ALL_REG, -(sp)
    move.w  enemy_hit, d0
    move.w  #10, d1
    divu    d1, d0
    
    * Tenth store at d1, d0 is digits
    move.w  d0, d1
    lsr.l   #8, d0
    lsr.l   #8, d0
    
    * get d1 seg value and store it at d3
    jsr     AssignSEGValue
    jsr     drawUITenth
    *move.l  d1, d3
    
    * get d0 seg value and restore d1 value at d1
    move.l  d0, d1
    jsr     AssignSEGValue
    * drawUI
    jsr     drawUI
    movem.l (sp)+, ALL_REG
    rts

* d0 take a number and assign correct seg value
* d1 - in
* d1 out
AssignSEGValue:
    cmp.l   #0, d1
    beq     .zero
    
    cmp.l   #1, d1
    beq     .one
    
    cmp.l   #2, d1
    beq     .two
    
    cmp.l   #3, d1
    beq     .three
    
    cmp.l   #4, d1
    beq     .four
    
    cmp.l   #5, d1
    beq     .five
    
    cmp.l   #6, d1
    beq     .six
    
    cmp.l   #7, d1
    beq     .seven
    
    cmp.l   #8, d1
    beq     .eight
    
    cmp.l   #9, d1
    beq     .nine
.zero
    move.l  #ZERO, d1
    bra     .return
.one
    move.l  #ONE, d1 
    bra     .return
.two
    move.l  #TWO, d1 
    bra     .return
.THREE
    move.l  #THREE, d1 
    bra     .return
.FOUR
    move.l  #FOUR, d1 
    bra     .return
.FIVE
    move.l  #FIVE, d1 
    bra     .return
.SIX
    move.l  #SIX, d1 
    bra     .return
.SEVEN
    move.l  #SEVEN, d1 
    bra     .return
.eight
    move.l  #eight, d1 
    bra     .return
.nine
    move.l  #nine, d1 
.return
    rts
    
    
*collision with player
* d0.w compared x
* d1.w player x
* d2.w compared y
* d3.w player y
* d6 is enemy speed
* return d4.b - 0 for no collision, 1 for collidedX , 2 for collideY, 3 for both collided
checkCollisionWithPlayer:
    movem.l d1-d3, -(sp)
    sub.w   d0, d1
    cmp.w   #0, d1
    blt     .XtoPos
    bra     .contX
.XtoPos
    not.w   d1              ; Invert the bits (D0 = ~D0)
    add.w   #1, d1
.contX
    cmp.l   d6, d1
    bgt     .checkY  // x not collided, if d1 bigger than enemy move dist
    move.b  #1, d4  // return not collided 
    bra     .checkY
.checkY
    sub.w   d2, d3
    cmp.w   #0, d3
    blt     .YtoPos
    bra     .contY
.YtoPos
    not.w   d3              ; Invert the bits (D0 = ~D0)
    add.w   #1, d3
.contY
    cmp.l   d6, d3
    blt     .colY
    * if y not collided, return either 0 or 1 in d4
    bra     .return
.colY
    cmp.b   #1, d4
    beq     .bothCol
    move.b  #2, d4  // only Y collide, return 2
    bra     .return
.bothCol
    move.b  #3, d4  // both collide return 3
    bra     .return
.return
    movem.l (sp)+,d1-d3
    rts
    
*collision projectile with projectile
* d0.w compared x
* d1.w projectile x
* d2.w compared y
* d3.w projectile y
* return d4.b - 0 for no collision, 1 for collision    
checkProjectileCol:
    movem.l d0-d3, -(sp)
    * make a copy of d3
    move.w  d3, d5
    * d5 is now projectile top
    sub.w   #PROJECTILE_HEIGHT, d5
    sub.w   #20, d5     ; (fine tuning) make the slime easier to hit
    * check if projectile is active
    cmp.w   #0, projectileActive
    beq     .noCol
    * check if x.left smaller than projectile
    cmp.w   d1, d0
    bgt     .noCol
    * check if x.right larger than projectile
    add.w   #ENEMY_WIDTH, d0
    cmp.w   d1, d0
    blt     .noCol
    * check if y.bottom is in projectile range
    cmp.w   d3, d2
    *enemy bottom is higher than projectile bottom, check lower then projectile top
    blt     .belowTop      
    *enemy bottom is lower than projectile bottom, check enemy top
    bra     .YTop          
.belowTop
    cmp.w   d5, d2
    * enemy bottom lower than enemy top
    bgt     .col
    bra     .noCol
.Ytop
    * d2 is now enemy top
    sub.w   #ENEMY_HEIGHT, d2
    * if enemy top smaller than projectile bottom, no collision
    cmp.w   d3, d2
    bgt     .noCol
    * if enemy top is higher than projectile bottom, must collide
.col
    move.l  #1, d4
    bra     .return
.noCol
    move.l  #0, d4    
.return
    movem.l (sp)+,d0-d3
    rts
    
    
* d0.l is seed    
random: 
    movem.l d1-d2, -(sp)
	MOVEQ	#4,d2		* do this 5 times
	MOVE.l	Prng32,d0	* get current 
Ninc0
	MOVEQ	#0,d1		* clear bit count
	ROR.l	#2,d0		* bit 31 -> carry
	BCC	Ninc1		* skip increment if =0

	ADDQ.b	#1,d1		* else increment bit count
Ninc1
	ROR.l	#3,d0		* bit 28 -> carry
	BCC	Ninc2		* skip increment if =0

	ADDQ.b	#1,d1		* else increment bit count
Ninc2
	ROL.l	#5,d0		* restore PRNG longword
	ROXR.b	#1,d1		* EOR bit into Xb
	ROXR.l	#1,d0		* shift bit to most significant
	DBF	d2,Ninc0	* loop 5 times

	MOVE.l	d0,Prng32	* save back to seed word
	movem.l (sp)+,d1-d2
	RTS

* A unit test for collision with player
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
.error
    move.l  d0, 1
    rts

Lose
    * delay frame, let last sound finish playing
    move.l  #DELAY_FRAME, d0
    move.l  #FRAME_DELAY_TIME, d1
    trap    #15
    * play lose sound effect
    move.l  #PLAY_SOUND_COMMAND, d0
    move.l  #4, d1
    trap    #15
    * draw lose screen and disable double buffer
    move.l  #DRAWING_MODE_TRAP_CODE,d0
    move.l  #DOUBLE_BUFFERED_OFF,d1
    trap    #15
    jsr	    clearScreen
    jsr     drawLose
    
    bra     done
Win 
    * delay frame, let last sound finish playing
    move.l  #DELAY_FRAME, d0
    move.l  #FRAME_DELAY_TIME, d1
    trap    #15
    * play win sound effect
    move.l  #PLAY_SOUND_COMMAND, d0
    move.l  #3, d1
    trap    #15
    * draw win screen and disable double buffer
    move.l  #DRAWING_MODE_TRAP_CODE,d0
    move.l  #DOUBLE_BUFFERED_OFF,d1
    trap    #15
    jsr	    clearScreen
    jsr     drawWin
    
    bra     done

* draw win screen
drawWin:
    clr.l    d1
    clr.l    d2     // clear d1d2, since later will move word into d1d2
    movem.l  d1-d2, -(sp)
    lea      FILEBUFFER3, a1
    move.w   #80,d1
    move.w   #350,d2
    move.l   #0, d3
    move.l   #270, d4
    move.l   #480, d5
    move.l   #270, d6

    bsr      bmp_draw
    cmp      #0, d0
    *bne      .error
    movem.l  (sp)+,d1-d2
    rts
    
* draw lose screen 
drawLose:
    clr.l    d1
    clr.l    d2     // clear d1d2, since later will move word into d1d2
    movem.l  d1-d2, -(sp)
    lea      FILEBUFFER4, a1

    move.w   #80,d1
    move.w   #350,d2
    move.l   #0, d3
    move.l   #270, d4
    move.l   #480, d5
    move.l   #270, d6

    bsr      bmp_draw
    cmp      #0, d0
    *bne      .error
    movem.l  (sp)+,d1-d2
    rts

    
Done
    SIMHALT             ; halt simulator

* Put variables and constants here
INPUT_FILE    dc.b  'vikingLeft.bmp',0
INPUT_FILE1   dc.b  'enemy.bmp',0
INPUT_FILE2   dc.b  'weapon.bmp',0
INPUT_FILE3   dc.b  'Win.bmp',0
INPUT_FILE4   dc.b  'Lose.bmp',0
INPUT_FILE5   dc.b  'vikingRight.bmp',0
INPUT_FILE6   dc.b  'attackRight.bmp',0
INPUT_FILE7   dc.b  'attackLeft.bmp',0
SOUND_FILE    dc.b   'hit.wav',0
SOUND_FILE1   dc.b   'gethit.wav',0
SOUND_FILE2   dc.b   'win.wav',0
SOUND_FILE3   dc.b   'lose.wav',0
ErrorLabel    dc.b    'An error was encountered',0
DebugLabel    dc.b    'left right shift pressed',0
PLAYER_X      dc.w    1
PLAYER_Y      dc.w    1
ENEMY_NUM     EQU     8     // need to be power of 4
ENEMY_ACTIVE ds.b    ENEMY_NUM
ENEMY_POS     ds.l    ENEMY_NUM
ENEMY_X       dc.w    1
ENEMY_Y       dc.w    1
attack_dir    dc.w    1
ENEMY_MOVE_DIST    ds.b    ENEMY_NUM
Prng32        ds.l	1		* random number store
powerMeterPercent       ds.l    1
projectileActive        ds.w    1
projectileThrown        ds.w    1
projectile_x            ds.w    1
projectile_y            ds.w    1
PROJECTILE_SPEED        ds.w    1
enemy_hit               ds.w    1
staff_frame             ds.w    1
playerL_frame           ds.w    1
playerR_frame           ds.w    1
attack_frame           ds.w    1
player_facing           ds.w    1
is_attacking            ds.w    1
staff_spriteFrames     
            dc.w  10, 54, 30, 54
            dc.w  40, 54, 37, 54
            dc.w  77, 54, 40, 54
            dc.w  120, 54, 42, 54
            dc.w  162, 54, 40, 54
            dc.w  202, 54, 44, 54
            dc.w  246, 54, 44, 54
            dc.w  290, 54, 40, 54
playerR_spriteFrames
            dc.w  0, 70, 72, 65   
            dc.w  72, 70, 72, 65  
            dc.w  144, 70, 72, 65 
            dc.w  214, 70, 72, 65
            dc.w  286, 70, 72, 65
            dc.w  358, 70, 72, 65
            dc.w  430, 70, 72, 65
            dc.w  502, 70, 72, 65   
playerL_spriteFrames
            dc.w  502, 70, 72, 65    
            dc.w  430, 70, 72, 65   
            dc.w  358, 70, 72, 65
            dc.w  286, 70, 72, 65
            dc.w  214, 70, 72, 65
            dc.w  142, 70, 72, 65 
            dc.w  72, 70, 72, 65
            dc.w  0, 70, 72, 65
attackR_spriteFrames
            dc.w  0, 70, 74, 65   
            dc.w  74, 70, 70, 65  
            dc.w  142, 70, 72, 65 
            dc.w  214, 70, 80, 65
            dc.w  294, 70, 85, 65
attackL_spriteFrames
            dc.w  310, 70, 72, 65
            dc.w  240, 70, 70, 65 
            dc.w  168, 70, 72, 65
            dc.w  85, 70, 80, 65
            dc.w  0, 70, 85, 65   
  
FILESIZE      EQU     $2E23F
FILESIZE1     EQU     $5000
FILESIZE2     EQU     $1F43F
FILESIZE3     EQU     $7E93F
              ds.l    0
FILEBUFFER    ds.b    FILESIZE
              ds.l    0
FILEBUFFER1   ds.b    FILESIZE1
              ds.l    0
FILEBUFFER2   ds.b    FILESIZE2 
              ds.l    0
FILEBUFFER3   ds.b    FILESIZE3
              ds.l    0
FILEBUFFER4   ds.l    FILESIZE3
              ds.l    0
FILEBUFFER5   ds.b    FILESIZE
              ds.l    0
FILEBUFFER6   ds.b    FILESIZE
              ds.l    0
FILEBUFFER7   ds.b    FILESIZE

              

    END    START        ; last line of source




























*~Font name~Fixedsys~
*~Font size~9~
*~Tab type~1~
*~Tab size~4~
