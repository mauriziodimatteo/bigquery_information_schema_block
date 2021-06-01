view: jobs_by_project_raw {
  # Temporary alias until refactor done
  extends: [jobs_in_project]
}

view: jobs {
  extends: [jobs_base]
  sql_table_name: `region-@{region}.INFORMATION_SCHEMA.JOBS_BY_@{scope}` ;;
}
view: jobs_in_project {
  extends: [jobs_base]
  sql_table_name: `region-@{region}.INFORMATION_SCHEMA.JOBS_BY_PROJECT` ;;
}

view: jobs_in_organization{
  extends: [jobs_base]
  sql_table_name: `region-@{region}.INFORMATION_SCHEMA.JOBS_BY_ORGANIZATION` ;;
}

view: jobs_base {
  # This is the main Information Schema table - with one row per job executed

  extension: required

  dimension: creation_timestamp_filter {
    # This is the partition column
    type: date_time
    sql: {% condition %} ${TABLE}.creation_time {% endcondition %};;

  }
  # This is the partition column
  dimension_group: creation {
    type: time
    timeframes: [
      raw,
      time,
      second,
      minute,
      minute5,
      minute15,
      minute30,
      hour,
      date,
      week,
      month,
      time_of_day,
      day_of_week,
      hour_of_day
    ]
    sql: ${TABLE}.creation_time ;;
  }

  ###### Creating Dynamic Reporting Periods for the Dashboard ########

  dimension: 3_hour_reporting_periods {
    sql: CASE
        WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),${creation_raw},hour) <= 3
        THEN 'Last 3 Hours'
        WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),${creation_raw},hour) > 3
        AND TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),${creation_raw},hour) <= 6
        THEN 'Previous 3 Hours'
        ELSE NULL
        END
       ;;
    label: "3 Hour Period"
    group_label: "Reporting Periods"
  }

  dimension: 6_hour_reporting_periods {
    sql: CASE
        WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),${creation_raw},hour) <= 6
        THEN 'Last 6 Hours'
        WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),${creation_raw},hour) > 6
        AND TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),${creation_raw},hour) <= 12
        THEN 'Previous 6 Hours'
        ELSE NULL
        END
       ;;
    label: "6 Hour Period"
    group_label: "Reporting Periods"
  }


  dimension: one_hour_reporting_periods {
    sql: CASE
        WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),${creation_raw},minute) <= 60
        THEN 'Last Hour'
        WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),${creation_raw},minute) > 60
        AND TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),${creation_raw},minute) <= 120
        THEN 'Previous Hour'
        ELSE NULL
        END
       ;;
    label: "One Hour Period"
    group_label: "Reporting Periods"
  }

  parameter: reporting_period_parameter {

    type: unquoted
    allowed_value: {
      label: "One Hour Reporting Period"
      value: "1"
    }
    allowed_value: {
      label: "3 Hour Reporting Period"
      value: "3"
    }
    allowed_value: {
      label: "6 Hour Reporting Period"
      value: "6"
    }
  }

  dimension: reporting_period {
    sql:
    {% if reporting_period_parameter._parameter_value == '1' %}
      ${one_hour_reporting_periods}
    {% elsif reporting_period_parameter._parameter_value == '3' %}
      ${3_hour_reporting_periods}
    {% elsif reporting_period_parameter._parameter_value == '6' %}
      ${6_hour_reporting_periods}
    {% else %}
      ${one_hour_reporting_periods}
    {% endif %};;
    label: "Dynamic Reporting Period"
    group_label: "Reporting Periods"
  }

  dimension: project_id {
    type: string
    sql: ${TABLE}.project_id ;;
  }

  dimension: project_number {
    hidden: yes
    type: string
    sql: ${TABLE}.project_number ;;
  }

##### Linking to the User Lookup Dashboard ######

  dimension: user_email {
    type: string
    sql: ${TABLE}.user_email ;;
    link: {
      label: "User Lookup Dashboard"
      url: "/dashboards/15?User={{ value }}"
      icon_url: "http://www.looker.com/favicon.ico"
    }
  }

  #### Linking to Job Lookup Dashboard and GCP Console ######

  dimension: job_id {
    primary_key: yes
    type: string
    sql: ${TABLE}.job_id ;;
    link: {
      label: "Job Lookup Dashboard"
      url: "/dashboards/3?Job%20Id={{ value }}&filter_config=%7B%22Job%20Id%22:%5B%7B%22type%22:%22%3D%22,%22values%22:%5B%7B%22constant%22:%22{{ value | encode_uri }}%22%7D,%7B%7D%5D,%22id%22:6%7D%5D%7D"
      icon_url: "http://www.looker.com/favicon.ico"
    }
    link: {
      label: "View Query History in BigQuery"
      url: "https://console.cloud.google.com/bigquery?j=bq:US:{{ value }}&page=queryresults"
      icon_url: "http://www.looker.com/favicon.ico"
    }
  }

  dimension: job_type {
    type: string
    sql: ${TABLE}.job_type ;;
  }

  dimension: statement_type {
    type: string
    sql: ${TABLE}.statement_type ;;
  }

  dimension_group: start_time {
    type: time
    timeframes: [
      raw,
      time,
      second,
      minute,
      hour,
      date,
      week,
      month,
      time_of_day,
      day_of_week,
      hour_of_day
    ]
    sql: ${TABLE}.start_time ;;
  }

  dimension_group: end_time {
    type: time
    timeframes: [
      raw,
      time,
      second,
      minute,
      hour,
      date,
      week,
      month,
      time_of_day,
      day_of_week,
      hour_of_day
    ]
    sql: ${TABLE}.end_time ;;
  }


#### Query Duration #####
  dimension: duration_milliseconds {
    type: number
    sql: TIMESTAMP_DIFF(${end_time_raw}, ${start_time_raw}, MILLISECOND) ;;
  }

  dimension: duration_seconds {
    type: number
    sql: TIMESTAMP_DIFF(${end_time_raw}, ${start_time_raw}, SECOND) ;;
  }

  measure: average_duration_seconds {
    type: average
    value_format_name: decimal_2
    sql: ${duration_seconds} ;;
  }

##### The Query Text field was removed from the Jobs by Organization Table #####

  dimension: query_text {
    type: string
    sql:{% if "@{scope}" == "ORGANIZATION"%} "Query text unavailable at ORGANIZATION scope " {%
      else %} ${TABLE}.query {% endif %};;
    html:
    <div style="white-space: normal;">{{rendered_value}}
    </div> ;;
  }

  dimension: state {
    type: string
    sql: ${TABLE}.state ;;
  }

  dimension: reservation_id {
    hidden: yes
    type: string
    sql: ${TABLE}.reservation_id ;;
  }

  dimension: total_bytes_processed {
    hidden: yes
    type: number
    sql: ${TABLE}.total_bytes_processed ;;
  }

  dimension: total_slot_ms {
    type: number
    description: "Total slots used multiplied by total MS the job ran for"
    sql: ${TABLE}.total_slot_ms ;;
  }

  dimension: error_result {
    type: string
    hidden: yes
    sql: ${TABLE}.error_result ;;
  }

  dimension: cache_hit {
    type: yesno
    sql: CAST(${TABLE}.cache_hit AS STRING);;
  }

  dimension: destination_table {
    hidden: yes
    type: string
    sql: ${TABLE}.destination_table ;;
  }

  dimension: destination_table_project_id {
    type: string
    sql:  ${destination_table}.project_id ;;
  }

  dimension: destination_table_dataset_id {
    type: string
    sql:  ${destination_table}.dataset_id ;;
  }

  dimension: destination_table_table_id {
    type: string
    sql:  ${destination_table}.table_id ;;
  }

  dimension: referenced_tables {
    hidden: yes
    type: string # Actually a nested struct
    sql: ${TABLE}.referenced_tables ;;
  }

  dimension: labels {
    hidden: yes
    type: string
    sql: ${TABLE}.labels ;;
  }

  dimension: timeline {
    hidden: yes
    type: string # Actually a nested struct
    sql: ${TABLE}.timeline ;;
  }

  dimension: job_stages {
    hidden: yes
    type: string  # Actually a nested struct
    sql: ${TABLE}.job_stages ;;
  }

#   parameter: bq_slots {
#     type: number
#     default_value: "2000"
#   }

  dimension: query_total_slot {
    label: "Total Slots Used for a Query"
    type: number
    sql: ${total_slot_ms}/NULLIF(${duration_milliseconds},0) ;;
    drill_fields: [job_id,total_gb_processed]
  }


  measure: average_slots_used {
    type: sum
    sql: ${query_total_slot} ;;
    value_format_name: decimal_2
    drill_fields: [detail*]
  }

#   measure: average_slot_utilization {
#     type: number
#     sql: ${average_slots_used}/{% parameter bq_slots %} ;;
#     value_format_name: percent_2
#     drill_fields: [job_id,average_slots_used]
#   }

  dimension: gb_processed {
    type: number
############# 10MB is the minimum billing amount for On-Demand pricing ##################
############# BQ uses Gibibytes (1024*1024*1024) instead of Gigabytes for processing ##############
    sql: IF(${total_bytes_processed} < 10.0 * (1024*1024),
      (10.0 * 1024 * 1024) * ARRAY_LENGTH(${referenced_tables}) / (1024*1024*1024),
      ${total_bytes_processed} / (1024*1024*1024))  ;;
    value_format_name: decimal_2
  }

  dimension: total_estimated_bytes_billed {
    # BigQuery bills for a minimum of 10MB for each table referenced.
    # Use this to help compute estimated bytes billed.
    type:  number
    label: "Estimated Bytes Billed"
    sql: IF(${total_bytes_processed} < 10.0 * (1024*1024),
      (10.0 * 1024 * 1024) * ARRAY_LENGTH(${referenced_tables}),
      ${total_bytes_processed})  ;;
  }

  measure: total_gb_processed {
    label: "Total GiB Processed"
    type: sum
    value_format_name: decimal_2
    sql: ${gb_processed} ;;
    drill_fields: [detail*]
  }

  measure: average_gb_processed {
    label: "Average GiB Processed"
    type: average
    value_format_name: decimal_2
    sql: ${gb_processed} ;;
    drill_fields: [detail*]
  }

  measure: estimated_tb_billed {
    label: "Estimated On-Demand TiB Billed"
    type:  sum
    value_format_name: decimal_2
    sql: ${total_estimated_bytes_billed} / POW(2, 40) ;;
  }

##### Model Creation costs more per GB than other Statement Types #######

  measure: estimated_on_demand_cost {
    label: "Estimated On-Demand Cost"
    type:  sum
    value_format_name: usd
    sql: CASE
          WHEN statement_type = 'CREATE_MODEL' THEN ROUND(${total_estimated_bytes_billed} / POW(2, 40)  * CAST(250.00 AS NUMERIC), 2)
          WHEN statement_type IN ('DELETE',
          'SELECT',
          'CREATE_TABLE_AS_SELECT',
          'INSERT',
          'MERGE') THEN ROUND(${total_estimated_bytes_billed} / POW(2, 40) * CAST(5.00 AS NUMERIC), 2)
          WHEN statement_type IS NULL THEN 0
        END ;;
  }

  measure: total_queries_ran {
    type: count_distinct
    sql: ${job_id} ;;
    filters: [
      job_type: "QUERY"
    ]
    drill_fields: [detail*]
  }

  measure: count_cached_queries {
    type: count_distinct
    sql: ${job_id};;
    filters: [cache_hit: "true"]
    drill_fields: [detail*]
  }

  measure: percent_of_queries_cached {
    type: number
    sql: ${count_cached_queries}/nullif(${count_of_jobs},0) ;;
    value_format_name: percent_2
    drill_fields: [detail*]
  }

#   parameter: dimension_paramenter {
#     type: unquoted
#     allowed_value: {
#       label: "By User"
#       value: "user_email"
#     }
#     allowed_value: {
#       label: "By Project"
#       value: "project_id"
#     }
#     allowed_value: {
#       label: "By Query"
#       value: "query"
#     }
#   }
#
#   dimension: dynamic_dimension {
#     type: string
#     sql: ${TABLE}.{% parameter dimension_paramenter %} ;;
#   }

  dimension: sum_shuffle_output_megabytes_spilled {
    type: number
    sql: (SELECT SUM(shuffle_output_bytes_spilled)/1000000 FROM UNNEST(${job_stages}));;
    value_format_name: decimal_2
    label: "Megabytes Spilled"
  }

  measure: average_shuffle_output_bytes_spilled {
    type: average
    sql: ${sum_shuffle_output_megabytes_spilled} ;;
    drill_fields: [detail*]
    value_format_name: decimal_2
  }

  measure: count_of_jobs {
    type: count
    filters: [job_id: "-NULL"]
    drill_fields: [detail*]
  }

  set: detail {
    fields: [
      creation_time,
      project_id,
      user_email,
      job_id,
      job_type,
      start_time_time,
      end_time_time,
      state,
      gb_processed,
      duration_seconds,
      total_slot_ms,
    ]
  }
}


##### NDT to filter by top N Projects #####

view: project_gb_rank_ndt {
  derived_table: {
    explore_source: jobs_by_project_raw_all_queries {
      column: project_id {field: jobs_by_project_raw_all_queries.project_id}
      column: total_gb_processed {field: jobs_by_project_raw_all_queries.total_gb_processed}
      derived_column: rank {sql: RANK() OVER (ORDER BY total_gb_processed DESC) ;;}
      bind_all_filters: yes
      sorts: [total_gb_processed: desc]
      timezone: "query_timezone"
    }
  }

  dimension: project_id {
    hidden: yes
  }

  dimension: rank {
    type: number
  }
}

view: jobs_by_project_raw__labels {

  dimension: labels {
    type: string
    sql: ${TABLE} ;;
  }
}


view: jobs_by_project_raw__job_stages__input_stages {

  dimension: input_stages {
    type: string
    sql: ${TABLE} ;;
  }
}

view: jobs_by_project_raw__job_stages__steps {

  dimension: steps {
    hidden: yes
    type: string
    sql: ${TABLE}.steps ;;
  }

  dimension: kind {
    type: string
    sql: ${TABLE}.kind ;;
  }

  dimension: substeps {
    type: string
    hidden: yes
    sql: ${TABLE}.substeps ;;
  }
}

view: jobs_by_project_raw__job_stages__steps__substeps  {

  dimension: substeps {
    type: string
    sql: ${TABLE} ;;
  }
}

##### NDT to filter Top N Referenced Datasets ######

view: referenced_datasets_ndt {
  derived_table: {
    explore_source: jobs_by_project_raw {
      column: referenced_dataset {field: jobs_by_project_raw__referenced_tables.referenced_dataset_id}
      column: total_jobs {field: jobs_by_project_raw.count_of_jobs}
      derived_column: rank {sql: RANK() OVER (ORDER BY total_jobs DESC) ;;}
      bind_all_filters: yes
      sorts: [total_jobs: desc]
      timezone: "query_timezone"
    }
  }

  dimension: referenced_dataset {
    hidden: yes
  }

  dimension: rank {
    type: number
  }

  dimension: referenced_dataset_ranked_total_jobs {
    sql: ${rank} || ' - ' || ${referenced_dataset} ;;
    order_by_field: rank
    type: string
  }
}
