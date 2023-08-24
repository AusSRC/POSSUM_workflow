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

include { download_possum } from "./modules/casda.nf"


workflow {
    sbid = "${params.SBID}"

    main:
        download_possum(sbid, "POSSUM", "${params.WORKDIR}/$sbid/${sbid}.json")
        get_evaluation_files(download_casda.out.sbid)

        conv_i(download_casda.out.i, get_evaluation_files.out.evaluation_files, "i")
        conv_q(download_casda.out.q, get_evaluation_files.out.evaluation_files, "q")
        conv_u(download_casda.out.u, get_evaluation_files.out.evaluation_files, "u")

        // Ionospheric correction
        ionospheric_correction(conv_q.out.cube_conv, conv_u.out.cube_conv)

        // Produce tile map
        hpx_tile_map(sbid, conv_i.out.cube_conv, get_evaluation_files.out.evaluation_files)

        // Tiling
        tile_i(sbid, hpx_tile_map.out.obs_id, conv_i.out.cube_conv, hpx_tile_map.out.tile_map, 'i')
        tile_q(sbid, hpx_tile_map.out.obs_id, ionospheric_correction.out.q_cube_corr, hpx_tile_map.out.tile_map, 'q')
        tile_u(sbid, hpx_tile_map.out.obs_id, ionospheric_correction.out.u_cube_corr, hpx_tile_map.out.tile_map, 'u')
        tile_w(sbid, hpx_tile_map.out.obs_id, download_casda.out.weights, hpx_tile_map.out.tile_map, 'w')
}