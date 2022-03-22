#!/usr/bin/env nextflow

nextflow.enable.dsl = 2
include { tiling } from './tiling/main'

workflow {
    image_cube = "${params.IMAGE_CUBE}"

    main: 
        tiling(image_cube)
}