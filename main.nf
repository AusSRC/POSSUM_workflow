#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { get_evaluation_files } from './modules/get_evaluation_files'
include {
    conv3d as conv_i;
    conv3d as conv_q;
    conv3d as conv_u;
    conv3d as conv_w;
} from './modules/convolution'
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

        conv_i(i_cube)
        conv_q(q_cube)
        conv_u(u_cube)
        conv_w(weights)

        // Ionospheric correction
        ionospheric_correction(conv_q.out.cube_conv, conv_u.out.cube_conv)

        // Tiling
        tile_i(sbid, conv_i.out.cube_conv, 'i', get_evaluation_files.out.evaluation_files, get_evaluation_files.out.metadata_dir)
        tile_q(sbid, ionospheric_correction.out.q_cube_corr, 'q', get_evaluation_files.out.evaluation_files, get_evaluation_files.out.metadata_dir)
        tile_u(sbid, ionospheric_correction.out.u_cube_corr, 'u', get_evaluation_files.out.evaluation_files, get_evaluation_files.out.metadata_dir)
        tile_w(sbid, conv_w.out.cube_conv, 'w', get_evaluation_files.out.evaluation_files, get_evaluation_files.out.metadata_dir)
}