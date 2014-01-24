.nolist
#include "kernel.inc"
#include "threadlist.lang"
.list
    .db 0, 50
.org 0
start:
    call getLcdLock
    call getKeypadLock

    call allocScreenBuffer
    xor a
    kld((topThread), a)
    kld((cursorWasAtBottom), a)
    ld ix, threadTable
redraw:
    kcall(drawInterface)
    kcall(drawThreads)
    kld(a, (totalThreads))
    or a
    kjp(z, noThreads)
    xor a
    kld((hasToRedraw), a)
mainLoop:
    call fastCopy
    call flushKeys
    call waitKey

    cp kClear
    kjp(z, launchCastle)
    cp kYEqu
    kjp(z, launchCastle)
    cp kUp
    jr z, doUp
    cp kDown
    jr z, doDown
    cp k2nd
    kjp(z, doSelect)
    cp kEnter
    kjp(z, doSelect)
    cp kDel
    kjp(z, doKill)
    cp kGraph
    kjp(z, doOptions)

    jr mainLoop

doUp:
    ld a, e
    cp 12
    jr nz, doUp_noScroll
    
    kld(a, (topThread))
    or a
    jr z, mainLoop
    dec a
    kld((topThread), a)
    xor a
    kld((cursorWasAtBottom), a)
    inc a
    kld((hasToRedraw), a)
    ld a, e
    add a, 6
doUp_noScroll:
    call putSpriteXOR
    sub 6
    ld e, a
    call putSpriteOR
    push hl
    push de
        push ix \ pop hl
        ; Loop to the previous available thread
doUp_loop:
        ld a, l
        sub 8
        ld l, a
        push hl
            inc hl \ ld e, (hl) \ inc hl \ ld d, (hl)
            ex de, hl \ inc hl \ inc hl
            ld a, (hl)
            cp 'K'
            jr z, _
                pop hl \ jr doDown_loop
_:          inc hl
            ld a, (hl)
            bit 1, a
            jr nz, _
                pop hl \ jr doUp_loop
_:      pop ix
    pop de
    pop hl
    kld(a, (hasToRedraw))
    or a
    kjp(nz, redraw)
    kjp(mainLoop)

doDown:
    kld(a, (topThread))
    ld c, a
    kld(a, (totalThreads))
    dec a
    sub c
    add a, a
    ld c, a
    add a, a
    add a, c
    add a, 12
    ld c, a
    ld a, e
    cp c
    kjp(z, mainLoop)
    cp 6 * 6 + 12
    jr nz, doDown_noScroll
    kld(hl, topThread)
    inc (hl)
    ld a, 1
    kld((cursorWasAtBottom), a)
    kld((hasToRedraw), a)
    ld a, e
    sub 6
doDown_noScroll:
    call putSpriteXOR
    add a, 6
    ld e, a
    call putSpriteOR
    push hl \ push de
        push ix \ pop hl
        ; Loop to the next available thread
doDown_loop:
        ld a, 8
        add a, l
        ld l, a
        push hl
            inc hl \ ld e, (hl) \ inc hl \ ld d, (hl)
            ex de, hl \ inc hl \ inc hl
            ld a, (hl)
            cp 'K'
            jr z, _
                pop hl \ jr doDown_loop
_:          inc hl
            ld a, (hl)
            bit 1, a
            jr nz, _
                pop hl \ jr doDown_loop
_:      pop ix
    pop de
    pop hl
    kld(a, (hasToRedraw))
    or a
    kjp(nz, redraw)
    kjp(mainLoop)

doSelect:
    call flushKeys
    di
    ld a, (ix)
    ld (hwLockLcd), a
    ld (hwLockKeypad), a
    call resumeThread
    jp killCurrentThread

doKill:
    xor a
    kld((cursorWasAtBottom), a)
    kld((topThread), a)
    di
    ld a, (ix)
    call killThread
    ei
    kjp(redraw - 3)

doOptions:
    xor a
    kld((cursorWasAtBottom), a)
    kld((topThread), a)
    kcall(drawOptions)
    call fastCopy

_:  call flushKeys
    call waitKey
    cp kClear
    kjp(z, redraw - 3)
    cp kGraph
    kjp(z, redraw - 3)
    cp k2nd
    jr z, doKill
    cp kEnter
    jr z, doKill
    jr -_

launchCastle:
    jr $
    kld(de, castlePath)
    di
    call launchProgram
    jp killCurrentThread

noThreads:
    kcall(drawInterface)
    ld b, 0
    ld de, lang_noPrograms_position
    kld(hl, noProgramsStr)
    call drawStr

    call fastCopy

_:  call flushKeys
    call waitKey

    cp kClear
    jr z, _
    cp kYEqu
    jr nz, -_

_:  call flushKeys
    jr launchCastle

drawThreads:
    xor a
    kld((totalThreads), a)
    kld((displayedThreads), a)
    ld de, (5 * 256) + 12
    ld hl, threadTable
    ld a, (activeThreads) \ dec a \ ld b, a
drawThreads_loop:
    push hl \ push de
        inc hl
        push de
            ld e, (hl) \ inc hl \ ld d, (hl)
            ld a, 2 \ add a, e \ ld e, a
            ex de, hl
            ld a, (hl)
            cp 'K' ; Check magic number
            jr z, _
                pop de \ jr skipThread
_:          inc hl
            ld a, (hl)
            bit 1, a ; Check thread visibility
            jr nz, _
                pop de \ jr skipThread
_:          inc hl
        pop de                                          ; please pleaaaaase optimize from here
        push hl
            kld(a, (totalThreads))
            kld(hl, topThread)
            cp (hl)
        pop hl
        jr nc, dispThread
    pop de
    ld a, -6
    add a, e
    ld e, a
    push de
        kld(a, (totalThreads))
        jr noDispThread
dispThread:
        ld c, a
        ld a, 6 * 6 + 12
        cp e
        ld a, c
        jr c, noDispThread
        call drawStr
noDispThread:
        inc a
        kld((totalThreads), a)
skipThread:                                             ; to here or everyone's gonna throw up
    pop de \ pop hl
    ld a, 6 \ add a, e \ ld e, a
    ld a, 8 \ add a, l \ ld l, a
    djnz drawThreads_loop

    kld(a, (topThread))
    or a
    jr z, noTopSprite
    kld(hl, moreThreadsUpSprite)
    ld b, 3
    ld de, 90 * 256 + 12
    call PutSpriteOR
noTopSprite:
    kld(a, (totalThreads))
    kld(hl, topThread)
    sub (hl)
    cp 8
    jr c, noBottomSprite
    kld(hl, moreThreadsDownSprite)
    ld b, 3
    ld de, 90 * 256 + 49
    call PutSpriteOR
noBottomSprite:
    kld(a, (cursorWasAtBottom))
    ld hl, 1 * 256 + 12
    or a
    jr z, $ + 6
        ld de, 6 * 6
        add hl, de
    ex de, hl
    ld b, 5
    kld(hl, selectionIndicatorSprite)
    call PutSpriteOR
    ret

drawInterface:
    call clearBuffer
    ; Castle top
    xor a
    ld l, 2
    call setPixel
    kld(hl, castleTopSprite)
    ld b, 12
    ld de, 0x0100
_:    ld a, 8
    push bc
        ld b, 3
        call putSpriteOR
    pop bc
    add a, d
    ld d, a
    djnz -_

    kld(hl, hotkeyLeftSprite)
    ld b, 8
    ld de, 0x0038
    call putSpriteOR

    kld(hl, hotkeyRightSprite)
    ld de, 0x5838
    call putSpriteOR

    kld(hl, hotkeyArrowLeftSprite)
    ld b, 5
    ld de, 0x003A
    call putSpriteOR

    kld(hl, hotkeyPlusSprite)
    ld b, 5
    ld de, 0x5A3A
    call putSpriteOR

    kld(hl, backStr)
    ld de, lang_castle_position
    call drawStr

    kld(hl, optionsStr)
    ld de, lang_options_position
    call drawStr

    kld(hl, runningProgramsStr)
    ld de, lang_runningPrograms_position
    call drawStr

    ld hl, 0x000A
    ld de, 0x5F0A
    call drawLine
    ret

drawOptions:
    kld(hl, hotkeyPlusSprite)
    ld de, 0x5A3A
    call putSpriteXOR

    kld(hl, hotkeyArrowUpSprite)
    ld de, 0x593A
    call putSpriteOR

    ld e, 55 - (61 - (lang_forceQuit_position >> 8))
    ld l, 48
    ld c, 96 - 54 + (61 - (lang_forceQuit_position >> 8))
    ld b, 56 - 47
    call rectOR
    ld e, 56 - (61 - (lang_forceQuit_position >> 8))
    ld l, 49
    ld c, 95 - 55 + (61 - (lang_forceQuit_position >> 8))
    ld b, 55 - 48
    call rectXOR
    ld e, 87
    ld l, 56
    ld c, 9
    ld b, 2
    call rectAND
    ld a, 87
    ld l, 57
    call setPixel

    kld(hl, forceQuitStr)
    ld de, lang_forceQuit_position
    call drawStr

    kld(hl, selectionIndicatorSprite)
    ld b, 5
    ld de, ((57  - (61 - (lang_forceQuit_position >> 8))) * 256) + 50
    call putSpriteOR
    ret

castleTopSprite: ; 8x3
    .db 0b11110000
    .db 0b10010000
    .db 0b10011111

hotkeyLeftSprite: ; 8x8
    .db 0b01111100
    .db 0b10000010
    .db 0b00000001
    .db 0b00000001
    .db 0b00000001
    .db 0b00000001
    .db 0b00000001
    .db 0b10000010

hotkeyRightSprite: ; 8x8
    .db 0b00111110
    .db 0b01000001
    .db 0b10000000
    .db 0b10000000
    .db 0b10000000
    .db 0b10000000
    .db 0b10000000
    .db 0b01000001

hotkeyPlusSprite: ; 8x5
    .db 0b00100000
    .db 0b00100000
    .db 0b11111000
    .db 0b00100000
    .db 0b00100000

hotkeyArrowLeftSprite: ; 8x5
    .db 0b0010000
    .db 0b0100000
    .db 0b1111100
    .db 0b0100000
    .db 0b0010000

hotkeyArrowUpSprite: ; 8x5
    .db 0b0010000
    .db 0b0111000
    .db 0b1010100
    .db 0b0010000
    .db 0b0010000

selectionIndicatorSprite: ; 8x5
    .db 0b10000000
    .db 0b11000000
    .db 0b11100000
    .db 0b11000000
    .db 0b10000000

moreThreadsUpSprite: ; 8x3
    .db 0b00100000
    .db 0b01110000
    .db 0b11111000
    
moreThreadsDownSprite: ; 8x3
    .db 0b11111000
    .db 0b01110000
    .db 0b00100000
    
backStr:
    .db lang_str_castle, 0
optionsStr:
    .db lang_str_options, 0
runningProgramsStr:
    .db lang_str_runningPrograms, 0
noProgramsStr:
    .db lang_str_noPrograms, 0
forceQuitStr:
    .db lang_str_forceQuit, 0

totalThreads:
    .db 0
topThread:
    .db 0
cursorWasAtBottom:
    .db 0
displayedThreads:
    .db 0
hasToRedraw:
    .db 0
    
castlePath:
    .db "/bin/castle", 0
