#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { get_evaluation_files } from './modules/get_evaluation_files'
include {
    conv3d as conv_i;
    conv3d as conv_q;
    conv3d as conv_u;
    pull_racstools_image;
} from './modules/convolution'
include { hpx_tile_map } from './modules/hpx_tile_map'
include { ionospheric_correction } from './modules/ionospheric_correction'
include {
    split_tiling as tile_i;
    split_tiling as tile_q;
    split_tiling as tile_u;
    split_tiling as tile_w;
} from './modules/tiling'

include {
    download;
    parse_possum_manifest;
} from "./modules/casda.nf"

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
} from './modules/objectstore'


workflow {
    sbid = "${params.SBID}"
    band = "${params.BAND}"

    main:
        download(sbid, "POSSUM", "${params.WORKDIR}/sbid_processing/$sbid/${sbid}.json")
        pull_racstools_image()
        parse_possum_manifest(download.out.manifest, pull_racstools_image.out.container)
        get_evaluation_files(sbid)

        conv_i(parse_possum_manifest.out.i_file, get_evaluation_files.out.evaluation_files, "i")
        conv_q(parse_possum_manifest.out.q_file, get_evaluation_files.out.evaluation_files, "q")
        conv_u(parse_possum_manifest.out.u_file, get_evaluation_files.out.evaluation_files, "u")

        // Ionospheric correction
        ionospheric_correction(conv_q.out.cube_conv, conv_u.out.cube_conv)

        // Produce tile map
        hpx_tile_map(sbid, conv_i.out.cube_conv, get_evaluation_files.out.evaluation_files, band)

        // Tiling
        tile_i(sbid, hpx_tile_map.out.obs_id, conv_i.out.cube_conv, hpx_tile_map.out.tile_map, 'i')
        tile_q(sbid, hpx_tile_map.out.obs_id, ionospheric_correction.out.q_cube_corr, hpx_tile_map.out.tile_map, 'q')
        tile_u(sbid, hpx_tile_map.out.obs_id, ionospheric_correction.out.u_cube_corr, hpx_tile_map.out.tile_map, 'u')
        tile_w(sbid, hpx_tile_map.out.obs_id, parse_possum_manifest.out.weights_file, hpx_tile_map.out.tile_map, 'w')

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
}
