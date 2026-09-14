function(gen_doc target_name)
    find_package(Doxygen)

    if (NOT DOXYGEN_FOUND)
        add_custom_target(${target_name})

        set_target_properties(${target_name} PROPERTIES
                DOXYGEN_HTML_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/html
                )
        return()
    endif ()

    set(options)
    set(one_value_args PROJECT_NAME PROJECT_NUMBER TEMPLATE_DIR OUTPUT_DIR)
    set(multi_value_args FILES IGNORE_PREFIX)
    cmake_parse_arguments(PARSE_ARGV 1
            GEN_DOC
            "${options}"
            "${one_value_args}"
            "${multi_value_args}"
            )

    set(DOXYGEN_EXTRACT_ALL YES)
    set(DOXYGEN_EXTRACT_PRIVATE YES)
    set(DOXYGEN_EXTRACT_STATIC YES)
    set(DOXYGEN_GENERATE_TAGFILE "${GEN_DOC_OUTPUT_DIR}/${GEN_DOC_TARGET}.tag")
    set(DOXYGEN_HAVE_DOT NO)
    set(DOXYGEN_HTML_COLORSTYLE_GAMMA 100)
    set(DOXYGEN_HTML_COLORSTYLE_HUE 239)
    set(DOXYGEN_HTML_COLORSTYLE_SAT 43)
    set(DOXYGEN_HTML_DYNAMIC_MENUS NO)
    set(DOXYGEN_HTML_FOOTER "${GEN_DOC_TEMPLATE_DIR}/footer.html")
    set(DOXYGEN_HTML_HEADER "${GEN_DOC_TEMPLATE_DIR}/header.html")
    set(DOXYGEN_HTML_STYLESHEET "${GEN_DOC_TEMPLATE_DIR}/customdoxygen.css")
    set(DOXYGEN_IGNORE_PREFIX ${GEN_DOC_IGNORE_PREFIX})
    set(DOXYGEN_LAYOUT_FILE "${GEN_DOC_TEMPLATE_DIR}/DoxygenLayout.xml")
    set(DOXYGEN_OPTIMIZE_OUTPUT_FOR_C YES)
    set(DOXYGEN_PROJECT_NAME "${GEN_DOC_PROJECT_NAME}")
    set(DOXYGEN_PROJECT_NUMBER "${GEN_DOC_PROJECT_NUMBER}")
    set(DOXYGEN_QUIET YES)
    set(DOXYGEN_SEARCHENGINE NO)

    doxygen_add_docs(${target_name}
            ${GEN_DOC_FILES}
            WORKING_DIRECTORY ${GEN_DOC_OUTPUT_DIR}
            ALL
            )

    set_target_properties(${target_name} PROPERTIES
            DOXYGEN_HTML_OUTPUT_DIRECTORY ${GEN_DOC_OUTPUT_DIR}/html
            )
endfunction(gen_doc)
