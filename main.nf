#!/usr/bin/env nextflow

nextflow.enable.dsl = 2
include { setup } from './modules/setup'
include { convolution as conv_i; convolution as conv_q; convolution as conv_u } from './modules/convolution'
include { ionospheric_correction } from './modules/ionospheric_correction'
include { tiling as tile_i; tiling as tile_q; tiling as tile_u } from './modules/tiling'

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
        tile_i(conv_i.out.cube_conv, "i")
        tile_q(ionospheric_correction.out.q_cube_corr, "q")
        tile_u(ionospheric_correction.out.u_cube_corr, "u")

        // Check if this completes another tile
        // Transfer to CADC
}