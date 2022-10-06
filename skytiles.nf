#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { sky_tiling } from './modules/sky_tiling'

workflow {
    config = "${params.CONFIG}"

    main:
        sky_tiling(config)
}