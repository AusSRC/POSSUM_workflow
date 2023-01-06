#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { get_evaluation_files } from './modules/get_evaluation_files'
include {
    conv3d as conv_i;
    conv3d as conv_q;
    conv3d as conv_u;
} from './modules/convolution'
include { hpx_tile_map } from './modules/hpx_tile_map'
include { ionospheric_correction } from './modules/ionospheric_correction'
include {
    split_tiling as tile_i;
    split_tiling as tile_q;
    split_tiling as tile_u;
    split_tiling as tile_w;
} from './modules/tiling'

workflow {
    sbid = "${params.SBID}"
    i_cube = "${params.I_CUBE}"
    q_cube = "${params.Q_CUBE}"
    u_cube = "${params.U_CUBE}"
    weights = "${params.WEIGHTS_CUBE}"

    main:
        get_evaluation_files(sbid)

        conv_i(i_cube, get_evaluation_files.out.evaluation_files, "i")
        conv_q(q_cube, get_evaluation_files.out.evaluation_files, "q")
        conv_u(u_cube, get_evaluation_files.out.evaluation_files, "u")

        // Ionospheric correction
        ionospheric_correction(conv_q.out.cube_conv, conv_u.out.cube_conv)

        // Produce tile map
        hpx_tile_map(sbid, conv_i.out.cube_conv, get_evaluation_files.out.evaluation_files)

        // Tiling
        tile_i(sbid, hpx_tile_map.out.obs_id, conv_i.out.cube_conv, hpx_tile_map.out.tile_map, 'i')
        tile_q(sbid, hpx_tile_map.out.obs_id, ionospheric_correction.out.q_cube_corr, hpx_tile_map.out.tile_map, 'q')
        tile_u(sbid, hpx_tile_map.out.obs_id, ionospheric_correction.out.u_cube_corr, hpx_tile_map.out.tile_map, 'u')
        tile_w(sbid, hpx_tile_map.out.obs_id, weights, hpx_tile_map.out.tile_map, 'w')
}