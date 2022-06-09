#!/usr/bin/env nextflow

nextflow.enable.dsl = 2
include { setup } from './setup/main'
include { convolution as conv_i; convolution as conv_q; convolution as conv_u } from './convolution/main'
include { ionospheric_correction } from './ionospheric_correction/main'
include { tiling as tile_i; tiling as tile_q; tiling as tile_u } from './tiling/main'

workflow {
    i_cube = "${params.I_CUBE}"
    q_cube = "${params.Q_CUBE}"
    u_cube = "${params.U_CUBE}"

    main:
        setup()
        conv_i(i_cube, setup.out.check)
        conv_q(q_cube, setup.out.check)
        conv_u(u_cube, setup.out.check)
        ionospheric_correction(conv_q.out.cube_conv, conv_u.out.cube_conv)
        tile_i(conv_i.out.cube_conv)
        tile_q(ionospheric_correction.out.q_cube_corr)
        tile_u(ionospheric_correction.out.u_cube_corr)
}