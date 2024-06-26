#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { mosaicking } from './modules/mosaicking'
include { get_pixel_set } from './modules/get_complete_tiles'
include { download_containers } from './modules/singularity'
include { objectstore_download_component; objectstore_upload_pixel } from './modules/objectstore'
include { add_to_fits_header } from './modules/metadata'

workflow {
    tile_id = "${params.TILE_ID}"
    obs_ids = "${params.OBS_IDS}"
    band = "${params.BAND}"
    survey_component = "${params.SURVEY_COMPONENT}"
    component_dir = "${params.WORKDIR}/components"
    tile_dir = "${params.WORKDIR}/tiles"
    csv_out = "${params.WORKDIR}/config/${tile_id}.${band}.map.json"

    main:
        download_containers()

        // Fetch from acacia if not on scratch
        objectstore_download_component(
            download_containers.out.ready,
            tile_id,
            obs_ids,
            component_dir,
            survey_component
        )

        // Run mosaicking
        get_pixel_set(
            tile_id,
            obs_ids,
            band,
            survey_component,
            component_dir,
            tile_dir,
            csv_out,
            objectstore_download_component.out.stdout
        )
        mosaicking(
            get_pixel_set.out.pixel_map,
            survey_component
        )
        add_to_fits_header(
            mosaicking.out.mosaic_files.collect(),
            get_pixel_set.out.pixel_map
        )

        // Push complete tiles to acacia
        objectstore_upload_pixel(
            add_to_fits_header.out.ready,
            tile_id,
            band,
            tile_dir,
            survey_component
        )
}
