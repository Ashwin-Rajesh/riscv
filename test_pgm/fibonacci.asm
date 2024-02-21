        addi sp, s0, 1024
main:
        addi    sp,sp,-32
        sw      ra,28(sp)
        sw      s0,24(sp)
        addi    s0,sp,32
        sw      zero,-20(s0)
        li      s11,1
        li      a5,9998336
        addi    s10,a5,1664
.L2:
        mv      a5,s10
        mv      a0,a5
        call    _Z5delayi
        mv      a4,s11
        lw      a5,-20(s0)
        add     a5,a4,a5
        mv      s11,a5
        mv      a4,s11
        lw      a5,-20(s0)
        sub     a5,a4,a5
        sw      a5,-20(s0)
        j       .L2
_Z5delayi:
        addi    sp,sp,-48
        sw      s0,44(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      zero,-20(s0)
.L5:
        lw      a4,-20(s0)
        lw      a5,-36(s0)
        bge     a4,a5,.L6
        lw      a5,-20(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
        j       .L5
.L6:
        nop
        lw      s0,44(sp)
        addi    sp,sp,48
        jr      ra