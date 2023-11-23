#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process file_complete_csv {
    executor = 'local'
    module = ['python/3.10.10']

    input:
        val csv_input
        val components_dir
        val output_dir
        val band
        val csv_out

    output:
        val csv_out, emit: csv_out_file

    script:
    """
    #!python

    import csv
    import glob
    import json

    from pathlib import Path

    components = '${components_dir}'
    output_dir = '${output_dir}'
    band = ${band}

    csv_out = '${csv_out}'
    csv_file = '${csv_input}'

    pixel_set = {}

    with open(csv_file) as csvfile:
        reader = csv.reader(csvfile)
        next(reader)
        for row in reader:
            i_list = []
            q_list = []
            u_list = []
            w_list = []

            pixel = row.pop(0)
            for obs in row:
                i_list += [str(Path(i).with_suffix('')) for i in glob.glob(f'/{components}/{obs}/survey/i/*{obs}*{pixel}*i*')]
                q_list += [str(Path(i).with_suffix('')) for i in glob.glob(f'/{components}/{obs}/survey/q/*{obs}*{pixel}*q*')]
                u_list += [str(Path(i).with_suffix('')) for i in glob.glob(f'/{components}/{obs}/survey/u/*{obs}*{pixel}*u*')]
                w_list += [str(Path(i).with_suffix('')) for i in glob.glob(f'/{components}/{obs}/survey/w/*{obs}*{pixel}*w*')]

            o_i = [f'{output_dir}/{pixel}/{band}/final_{band}_{pixel}_i', f'{output_dir}/{pixel}/{band}/final_{band}_{pixel}_w']
            o_q = [f'{output_dir}/{pixel}/{band}/final_{band}_{pixel}_q', f'{output_dir}/{pixel}/{band}/final_{band}_{pixel}_w']
            o_u = [f'{output_dir}/{pixel}/{band}/final_{band}_{pixel}_u', f'{output_dir}/{pixel}/{band}/final_{band}_{pixel}_w']

            i_list.sort()
            q_list.sort()
            u_list.sort()
            w_list.sort()

            pixel_set[pixel] = {"i": {"pixel": pixel, "band": band, "stokes": "i", "input": [i_list, w_list], "output": o_i}, 
                                "q": {"pixel": pixel, "band": band, "stokes": "q", "input": [q_list, w_list], "output": o_q}, 
                                "u": {"pixel": pixel, "band": band, "stokes": "u", "input": [u_list, w_list], "output": o_u}}

    with open(csv_out, 'w') as f:
        data = json.dumps(pixel_set)
        f.write(data)
    """
}

import groovy.json.JsonSlurper

process parse_json {
    executor = 'local'

    input:
        val csv_input

    output:
        val pixel_map, emit: pixel_map_out

    exec:
        def jsonSlurper = new JsonSlurper()
        def f = new File(csv_input)
        pixel_map = jsonSlurper.parseText(f.text)
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow get_pixel_set {
    take:
        csv_input
        components_dir
        output_dir
        band
        csv_out

    main:
        file_complete_csv(csv_input, components_dir, output_dir, band, csv_out)
        parse_json(file_complete_csv.out.csv_out_file)

    emit:
        pixel_map = parse_json.out.pixel_map_out
}

// ----------------------------------------------------------------------------------------
