#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { mosaicking } from './modules/mosaicking'
include { get_pixel_set } from './modules/get_complete_tiles'

workflow {

    csv_input = '/home/dpallot/POSSUM_workflow/shapley_0.7deg/PSM-shapley_REPEAT.csv'
    component_dir = '/scratch/ja3/possum_survey/survey/components'
    output_dir = '/scratch/ja3/possum_survey/survey/tiles'
    csv_out = '/scratch/ja3/possum_survey/survey/tile_processing/PSM-shapley_REPEAT.json'
    band = 1

    main:
        get_pixel_set(csv_input, 
                      component_dir, 
                      output_dir, 
                      band, 
                      csv_out)

        mosaicking(get_pixel_set.out.pixel_map)

}