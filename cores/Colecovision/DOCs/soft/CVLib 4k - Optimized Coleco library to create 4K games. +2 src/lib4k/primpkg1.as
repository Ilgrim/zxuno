    psect   text
    
    ; Note : This function works only if the WORK_BUFFER index
    ;        is set in the rom header at address 8006-8007.
    ;        WORK_BUFFER[0..7] to get source data
    ;        WORK_BUFFER[8..15] to set destination data

    global  _reflect_horizontal
    ; reflect_horizontal ( table_code : 0 = sprite_name
    ;                                   1 = sprite_generator
    ;                                   2 = name (chars on screen)
    ;                                   3 = pattern (chars pattern)
    ;                                   4 = color (chars color)
    ;                      source : index to source in vram 
    ;                      destination : index to dest. in vram
    ;                      count : number of "graphic items" to do
    ;                    )
    ;
    ; Desc. : To reflect graphic data around horizontal axis 

_reflect_horizontal:

    push    ix
    ld      ix,4
    add     ix,sp
    ld      a,(ix+0)
    ld      e,(ix+2)
    ld      d,(ix+3)
    ld      l,(ix+4)
    ld      h,(ix+5)
    ld      c,(ix+6)
    ld      b,(ix+7)
    call    01f6dh  ; Coleco's bios reflect_horizontal function
    pop     ix
    ret
