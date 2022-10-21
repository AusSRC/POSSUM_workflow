#!/usr/bin/env nextflow

nextflow.enable.dsl = 2
include { download } from './modules/download'
include { convolution as conv_i; convolution as conv_q; convolution as conv_u; convolution as conv_w } from './modules/convolution'
include { ionospheric_correction } from './modules/ionospheric_correction'
include { tiling as tile_i; tiling as tile_q; tiling as tile_u; tiling as tile_w } from './modules/tiling'

workflow {
    sbid = "${params.SBID}"
    // i_cube = "${params.I_CUBE}"
    // q_cube = "${params.Q_CUBE}"
    // u_cube = "${params.U_CUBE}"
    // weights = "${params.WEIGHTS_CUBE}"
    tiling_map = "${params.TILING_MAP}"

    main:
        download(sbid)

        conv_i(download.out.i_cube)
        conv_q(download.out.q_cube)
        conv_u(download.out.u_cube)

        // Flagging to be added

        ionospheric_correction(conv_q.out.cube_conv, conv_u.out.cube_conv)

        tile_i(conv_i.out.cube_conv, tiling_map)
        tile_q(ionospheric_correction.out.q_cube_corr, tiling_map)
        tile_u(ionospheric_correction.out.u_cube_corr, tiling_map)
        tile_w(download.out.weights, tiling_map)

        // Mosaicking
        // Check if this completes another tile

        // Transfer to CADC
}