#!/usr/bin/env nextflow

nextflow.enable.dsl = 2
include { mosaicking } from './mosaicking/main'

workflow {
    sbids = Channel.of(params.SBIDS.split(','))

    main: 
        mosaicking(sbids)
}