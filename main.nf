#!/usr/bin/env nextflow

nextflow.enable.dsl = 2
include { mosaicking } from './mosaicking/main'

workflow {
    // sbids = Channel.of(params.SBIDS.split(','))
    cubes = Channel.of(params.CUBES.split(','))

    main: 
        mosaicking(cubes)
}