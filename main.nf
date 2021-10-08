#!/usr/bin/env nextflow

nextflow.enable.dsl = 2
include { mosaicking } from './mosaicking/main'
include { ionospheric_correction } from './ionospheric_correction/main'

workflow {
    cubes = Channel.of(params.CUBES.split(','))

    main: 
        ionospheric_correction(cubes.collect())
        mosaicking(ionospheric_correction.out.cubes)
}