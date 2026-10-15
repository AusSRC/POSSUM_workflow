#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { download_containers } from './pipeline_components/nextflow/modules/singularity'
include { mosaicking } from './modules/mosaicking'
include { get_pixel_set } from './modules/get_complete_tiles'
include { objectstore_download_component; objectstore_upload_pixel } from './modules/objectstore'

workflow {
    tile_id = "${params.TILE_ID}"
    obs_ids = "${params.OBS_IDS}"
    band = "${params.BAND}"
    survey_component = "${params.SURVEY_COMPONENT}"
    component_dir = "${params.WORKDIR}/components"
    tile_dir = "${params.WORKDIR}/tiles"
    csv_out = "${params.WORKDIR}/config/${tile_id}.${band}.map.json"

    main:
        // linmos is run from the singularity image directly, so it needs to be in the cache
        download_containers([params.ASKAPSOFT_IMAGE])

        // Fetch from acacia if not on scratch
        objectstore_download_component(
            tile_id,
            obs_ids,
            component_dir,
            survey_component
        )

        // Run mosaicking once the components and the linmos container are downloaded
        ready = objectstore_download_component.out.stdout
            .combine(download_containers.out.ready)
            .map { true }

        get_pixel_set(
            tile_id,
            obs_ids,
            band,
            survey_component,
            component_dir,
            tile_dir,
            csv_out,
            ready
        )
        mosaicking(
            get_pixel_set.out.pixel_map.flatMap(),
            survey_component
        )

        // Push complete tiles to acacia
        objectstore_upload_pixel(
            mosaicking.out.mosaic_files.collect(),
            tile_id,
            band,
            tile_dir,
            survey_component
        )
}
