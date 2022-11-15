#!/usr/bin/env nextflow

nextflow.enable.dsl = 2
include { download } from './modules/download'
include {
    convolution as conv_i;
    convolution as conv_q;
    convolution as conv_u;
    convolution as conv_w;
} from './modules/convolution'
include { ionospheric_correction } from './modules/ionospheric_correction'
include {
    tiling as tile_i;
    tiling as tile_q;
    tiling as tile_u;
    tiling as tile_w;
} from './modules/tiling'
include {
    get_complete_tiles as get_complete_tiles_i;
    get_complete_tiles as get_complete_tiles_q;
    get_complete_tiles as get_complete_tiles_u;
    get_complete_tiles as get_complete_tiles_w;
} from './modules/get_complete_tiles'
include { get_evaluation_files } from './modules/get_evaluation_files'
include {
    mosaicking as mosaicking_i;
    mosaicking as mosaicking_q;
    mosaicking as mosaicking_u;
} from './modules/mosaicking'

workflow {
    sbid = "${params.SBID}"
    i_cube = "${params.I_CUBE}"
    q_cube = "${params.Q_CUBE}"
    u_cube = "${params.U_CUBE}"
    weights = "${params.WEIGHTS_CUBE}"

    main:
        // download(sbid)
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

        // Get complete tiles
        get_complete_tiles_i(tile_i.out.obs_id, "i")
        get_complete_tiles_q(tile_q.out.obs_id, "q")
        get_complete_tiles_u(tile_u.out.obs_id, "u")
        get_complete_tiles_w(tile_w.out.obs_id, "w")

        // Mosaicking
        mosaicking_i(
            get_complete_tiles_i.out.tiles,
            get_complete_tiles_w.out.tiles,
            "i"
        )
        mosaicking_q(
            get_complete_tiles_q.out.tiles,
            get_complete_tiles_w.out.tiles,
            "q"
        )
        mosaicking_u(
            get_complete_tiles_u.out.tiles,
            get_complete_tiles_w.out.tiles,
            "u"
        )
}