#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { download_possum; evaluation_files } from './modules/casda'
include {
    conv3d as conv_i;
    conv3d as conv_q;
    conv3d as conv_u;
} from './modules/convolution'
include { ionospheric_correction } from './modules/ionospheric_correction'
include { hpx_tile_map } from './modules/hpx_tile_map'
include {
    split_tiling as tile_i;
    split_tiling as tile_q;
    split_tiling as tile_u;
    split_tiling as tile_w;
} from './modules/tiling'
include {
    provenance as provenance_i;
    provenance as provenance_q;
    provenance as provenance_u;
    provenance as provenance_w;
} from './modules/metadata'
include {
    objectstore_upload_stokes_component as upload_i;
    objectstore_upload_stokes_component as upload_q;
    objectstore_upload_stokes_component as upload_u;
    objectstore_upload_stokes_component as upload_w;
    objectstore_upload_frion_predict;
} from './modules/objectstore'


workflow {
    sbid = "${params.SBID}"
    band = "${params.BAND}"

    main:
        // Downloads (image cubes, evaluation files, beamlog)
        download_possum(sbid)
        evaluation_files(sbid)

        // Common beam convolution
        conv_i(download_possum.out.i_file, evaluation_files.out.evaluation_files, "i")
        conv_q(download_possum.out.q_file, evaluation_files.out.evaluation_files, "q")
        conv_u(download_possum.out.u_file, evaluation_files.out.evaluation_files, "u")

        // Ionospheric correction
        ionospheric_correction(conv_q.out.cube_conv, conv_u.out.cube_conv)

        // Produce tile map
        hpx_tile_map(sbid, conv_i.out.cube_conv, evaluation_files.out.evaluation_files, band)

        // Tiling
        tile_i(hpx_tile_map.out.obs_id, conv_i.out.cube_conv, hpx_tile_map.out.tile_map, 'i')
        tile_q(hpx_tile_map.out.obs_id, ionospheric_correction.out.q_cube_corr, hpx_tile_map.out.tile_map, 'q')
        tile_u(hpx_tile_map.out.obs_id, ionospheric_correction.out.u_cube_corr, hpx_tile_map.out.tile_map, 'u')
        tile_w(hpx_tile_map.out.obs_id, download_possum.out.weights_file, hpx_tile_map.out.tile_map, 'w')

        // Metadata
        provenance_i(sbid, hpx_tile_map.out.obs_id, "survey", "i", tile_i.out.ready)
        provenance_q(sbid, hpx_tile_map.out.obs_id, "survey", "q", tile_q.out.ready)
        provenance_u(sbid, hpx_tile_map.out.obs_id, "survey", "u", tile_u.out.ready)
        provenance_w(sbid, hpx_tile_map.out.obs_id, "survey", "w", tile_w.out.ready)

        // upload cubes to Acacia
        upload_i(provenance_i.out.ready, hpx_tile_map.out.obs_id, "survey", "i")
        upload_q(provenance_q.out.ready, hpx_tile_map.out.obs_id, "survey", "q")
        upload_u(provenance_u.out.ready, hpx_tile_map.out.obs_id, "survey", "u")
        upload_w(provenance_w.out.ready, hpx_tile_map.out.obs_id, "survey", "w")
        objectstore_upload_frion_predict(provenance_q.out.ready, sbid, hpx_tile_map.out.obs_id, "survey")

        // clear working directory
        // TBA
}
