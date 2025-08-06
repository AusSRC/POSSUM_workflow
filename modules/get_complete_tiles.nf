#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process file_complete_csv {
    input:
        val tile_id
        val obs_ids
        val band
        val survey_component
        val components_dir
        val output_dir
        val csv_out
        val ready

    output:
        val csv_out, emit: csv_out_file

    script:
    if (survey_component == 'mfs')
        """
        #!python3

        import glob
        import json

        from pathlib import Path

        pixel = '${tile_id}'
        obs_ids = '${obs_ids}'
        band = ${band}
        survey_component = '${survey_component}'
        components = '${components_dir}'
        output_dir = '${output_dir}'
        csv_out = '${csv_out}'

        obs_str = obs_ids.replace(' ', '').replace(',', '_')

        pixel_set = {}
        i_list = []
        w_list = []

        for obs in obs_ids.split(','):
            i_list += [str(Path(i).with_suffix('')) for i in glob.glob(f'{components}/{obs}/{survey_component}/i/*{obs}*{pixel}*i*.fits')]
            w_list += [str(Path(i).with_suffix('')) for i in glob.glob(f'{components}/{obs}/{survey_component}/w/weights*{obs}*{pixel}*.fits')]

            o_i = [f'{output_dir}/{pixel}/{survey_component}/POSSUM.{survey_component}.band{band}.{obs_str}.{pixel}.i', f'{output_dir}/{pixel}/{survey_component}/POSSUM.{survey_component}.band{band}.{obs_str}.{pixel}.w']

            i_list.sort()
            w_list.sort()

        pixel_set[pixel] = {"i": {"pixel": pixel, "band": band, "stokes": "i", "input": [i_list, w_list], "output": o_i}}

        with open(csv_out, 'w') as f:
            data = json.dumps(pixel_set)
            f.write(data)
        """
    else
        """
        #!python3

        import glob
        import json

        from pathlib import Path

        pixel = '${tile_id}'
        obs_ids = '${obs_ids}'
        band = ${band}
        survey_component = '${survey_component}'
        components = '${components_dir}'
        output_dir = '${output_dir}'
        csv_out = '${csv_out}'

        obs_str = obs_ids.replace(' ', '').replace(',', '_')

        pixel_set = {}
        i_list = []
        q_list = []
        u_list = []
        w_list = []

        for obs in obs_ids.split(','):
            i_list += [str(Path(i).with_suffix('')) for i in glob.glob(f'{components}/{obs}/{survey_component}/i/*{obs}*{pixel}*i*')]
            q_list += [str(Path(i).with_suffix('')) for i in glob.glob(f'{components}/{obs}/{survey_component}/q/*{obs}*{pixel}*q*')]
            u_list += [str(Path(i).with_suffix('')) for i in glob.glob(f'{components}/{obs}/{survey_component}/u/*{obs}*{pixel}*u*')]
            w_list += [str(Path(i).with_suffix('')) for i in glob.glob(f'{components}/{obs}/{survey_component}/w/*{obs}*{pixel}*w*')]

            o_i = [f'{output_dir}/{pixel}/{survey_component}/POSSUM.band{band}.{obs_str}.{pixel}.i', f'{output_dir}/{pixel}/{survey_component}/POSSUM.band{band}.{obs_str}.{pixel}.w']
            o_q = [f'{output_dir}/{pixel}/{survey_component}/POSSUM.band{band}.{obs_str}.{pixel}.q', f'{output_dir}/{pixel}/{survey_component}/POSSUM.band{band}.{obs_str}.{pixel}.w']
            o_u = [f'{output_dir}/{pixel}/{survey_component}/POSSUM.band{band}.{obs_str}.{pixel}.u', f'{output_dir}/{pixel}/{survey_component}/POSSUM.band{band}.{obs_str}.{pixel}.w']

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
        val pixel_map, emit: pixel_map

    exec:
        def jsonSlurper = new JsonSlurper()
        def f = new File(csv_input)
        pixel_map = jsonSlurper.parseText(f.text)
}

process process_pixel_map {
    executor = 'local'

    input:
        val pixel

    output:
        val pixel_stokes_list, emit: pixel_stokes_list

    exec:
        pixel_stokes_list = pixel.getValue()
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow get_pixel_set {
    take:
        tile_id
        obs_ids
        band
        survey_component
        components_dir
        output_dir
        csv_out
        ready

    main:
        file_complete_csv(tile_id, obs_ids, band, survey_component, components_dir, output_dir, csv_out, ready)
        parse_json(file_complete_csv.out.csv_out_file)
        process_pixel_map(parse_json.out.pixel_map.flatMap())

    emit:
        pixel_map = process_pixel_map.out.pixel_stokes_list
}

// ----------------------------------------------------------------------------------------
