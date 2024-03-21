#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

process objectstore_upload_component {
    input:
        val ready
        val obs_id
        val subdir

    script:
        """
        rclone --s3-chunk-size=128M --progress copy -u --ignore-checksum "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/${obs_id}/${subdir}" "pawsey0980:possum/components/${obs_id}/${subdir}"
        """
}

process objectstore_download_component {
    input:
        val ready
        val tile_id
        val obs_ids
        val component_dir
        val survey_component

    output:
        stdout emit: stdout

    script:
        """
        IFS=","
        obs_ids="${obs_ids}"
        for obs_id in \$obs_ids
        do
            rclone --s3-chunk-size=128M --progress copy -u --ignore-checksum --include="*${tile_id}*" "pawsey0980:possum/components/\$obs_id/${survey_component}" "${component_dir}/\$obs_id/${survey_component}"
        done
        """
}

process objectstore_upload_pixel {
    input:
        val ready
        val tile_id
        val band
        val tile_dir
        val survey_component

    script:
        """
        rclone --s3-chunk-size=128M --progress copy -u --ignore-checksum --include="*band${band}*${tile_id}*" "${tile_dir}/${tile_id}/${survey_component}" "pawsey0980:possum/tiles/${survey_component}/${tile_id}"
        """
}