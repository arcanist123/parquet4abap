"! <p class="shorttext synchronized">Parquet: Thrift Compact Protocol writer</p>
"! Writes Thrift Compact Protocol values to a growing <em>xstring</em>.
"! Unknown fields passed to write_struct_begin are written back between the
"! known fields in field id order, so a struct whose fields are written in
"! ascending id order comes out as it was read.
CLASS zparq2a_cl_thrift_writer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.

    "! @parameter unknown | fields to write back unchanged
    METHODS write_struct_begin
      IMPORTING
        unknown TYPE zparq2a_if_thrift=>ty_fields OPTIONAL.

    METHODS write_struct_end
      RAISING
        zparq2a_cx_error.

    "! Field header for a value written next with write_i32, write_list_begin, ...
    METHODS write_field_begin
      IMPORTING
        id   TYPE i
        type TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS write_bool_field
      IMPORTING
        id    TYPE i
        value TYPE abap_bool
      RAISING
        zparq2a_cx_error.

    METHODS write_i8_field
      IMPORTING
        id    TYPE i
        value TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS write_i16_field
      IMPORTING
        id    TYPE i
        value TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS write_i32_field
      IMPORTING
        id    TYPE i
        value TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS write_i64_field
      IMPORTING
        id    TYPE i
        value TYPE int8
      RAISING
        zparq2a_cx_error.

    METHODS write_binary_field
      IMPORTING
        id    TYPE i
        value TYPE xstring
      RAISING
        zparq2a_cx_error.

    METHODS write_string_field
      IMPORTING
        id    TYPE i
        value TYPE string
      RAISING
        zparq2a_cx_error.

    "! Field header and list header
    METHODS write_list_field
      IMPORTING
        id           TYPE i
        element_type TYPE i
        size         TYPE i
      RAISING
        zparq2a_cx_error.

    "! A struct-valued union member with an empty or raw struct
    METHODS write_union_field
      IMPORTING
        id    TYPE i
        value TYPE zparq2a_if_thrift=>ty_union
      RAISING
        zparq2a_cx_error.

    "! A boolean list element
    METHODS write_bool
      IMPORTING
        value TYPE abap_bool.

    "! @parameter value | -128..127
    METHODS write_i8
      IMPORTING
        value TYPE i
      RAISING
        zparq2a_cx_error.

    "! @parameter value | -32768..32767
    METHODS write_i16
      IMPORTING
        value TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS write_i32
      IMPORTING
        value TYPE i.

    METHODS write_i64
      IMPORTING
        value TYPE int8.

    METHODS write_binary
      IMPORTING
        value TYPE xstring.

    "! Writes text as UTF-8 binary
    METHODS write_string
      IMPORTING
        value TYPE string
      RAISING
        zparq2a_cx_error.

    "! Header of a list or set
    METHODS write_list_begin
      IMPORTING
        element_type TYPE i
        size         TYPE i
      RAISING
        zparq2a_cx_error.

    "! A union whose members are structs, see ZPARQ2A_IF_THRIFT=&gt;TY_UNION
    METHODS write_union
      IMPORTING
        value TYPE zparq2a_if_thrift=>ty_union
      RAISING
        zparq2a_cx_error.

    "! Appends encoded bytes as they are
    METHODS write_raw
      IMPORTING
        value TYPE xstring.

    METHODS get_result
      RETURNING
        VALUE(result) TYPE xstring.

  PROTECTED SECTION.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_frame,
        last_id TYPE i,
        pending TYPE zparq2a_if_thrift=>ty_fields,
      END OF ty_frame,
      ty_frames TYPE STANDARD TABLE OF ty_frame WITH EMPTY KEY.

    DATA writer TYPE REF TO zparq2a_cl_byte_writer.
    DATA frames TYPE ty_frames.

    METHODS write_header
      IMPORTING
        id   TYPE i
        type TYPE i
      RAISING
        zparq2a_cx_error.

    "! Writes the pending unknown fields with an id below the given one
    METHODS flush_unknown
      IMPORTING
        below TYPE i
      RAISING
        zparq2a_cx_error.

ENDCLASS.


CLASS zparq2a_cl_thrift_writer IMPLEMENTATION.

  METHOD constructor.
    writer = NEW #( ).
  ENDMETHOD.

  METHOD write_struct_begin.
    DATA frame TYPE ty_frame.

    frame-pending = unknown.
    SORT frame-pending STABLE BY id.
    APPEND frame TO frames.
  ENDMETHOD.

  METHOD write_struct_end.
    flush_unknown( 32768 ).
    writer->write_byte( zparq2a_if_thrift=>c_type-stop ).
    DELETE frames INDEX lines( frames ).
  ENDMETHOD.

  METHOD write_field_begin.
    flush_unknown( id ).
    write_header( id = id type = type ).
  ENDMETHOD.

  METHOD write_bool_field.
    IF value = abap_true.
      write_field_begin( id = id type = zparq2a_if_thrift=>c_type-bool_true ).
    ELSE.
      write_field_begin( id = id type = zparq2a_if_thrift=>c_type-bool_false ).
    ENDIF.
  ENDMETHOD.

  METHOD write_i8_field.
    write_field_begin( id = id type = zparq2a_if_thrift=>c_type-byte ).
    write_i8( value ).
  ENDMETHOD.

  METHOD write_i16_field.
    write_field_begin( id = id type = zparq2a_if_thrift=>c_type-i16 ).
    write_i16( value ).
  ENDMETHOD.

  METHOD write_i32_field.
    write_field_begin( id = id type = zparq2a_if_thrift=>c_type-i32 ).
    write_i32( value ).
  ENDMETHOD.

  METHOD write_i64_field.
    write_field_begin( id = id type = zparq2a_if_thrift=>c_type-i64 ).
    write_i64( value ).
  ENDMETHOD.

  METHOD write_binary_field.
    write_field_begin( id = id type = zparq2a_if_thrift=>c_type-binary ).
    write_binary( value ).
  ENDMETHOD.

  METHOD write_string_field.
    write_field_begin( id = id type = zparq2a_if_thrift=>c_type-binary ).
    write_string( value ).
  ENDMETHOD.

  METHOD write_list_field.
    write_field_begin( id = id type = zparq2a_if_thrift=>c_type-list ).
    write_list_begin( element_type = element_type size = size ).
  ENDMETHOD.

  METHOD write_union_field.
    write_field_begin( id = id type = zparq2a_if_thrift=>c_type-struct ).
    write_union( value ).
  ENDMETHOD.

  METHOD write_bool.
    IF value = abap_true.
      writer->write_bytes( '01' ).
    ELSE.
      writer->write_bytes( '02' ).
    ENDIF.
  ENDMETHOD.

  METHOD write_i8.
    IF value < -128 OR value > 127.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Value { value } is outside the range of i8|.
    ENDIF.
    IF value < 0.
      writer->write_byte( value + 256 ).
    ELSE.
      writer->write_byte( value ).
    ENDIF.
  ENDMETHOD.

  METHOD write_i16.
    IF value < -32768 OR value > 32767.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Value { value } is outside the range of i16|.
    ENDIF.
    write_i32( value ).
  ENDMETHOD.

  METHOD write_i32.
    write_i64( CONV #( value ) ).
  ENDMETHOD.

  METHOD write_i64.
    writer->write_zigzag_varint( value ).
  ENDMETHOD.

  METHOD write_binary.
    writer->write_varint( xstrlen( value ) ).
    writer->write_bytes( value ).
  ENDMETHOD.

  METHOD write_string.
    write_binary( zparq2a_cl_bytes=>utf8_encode( value ) ).
  ENDMETHOD.

  METHOD write_list_begin.
    IF element_type < zparq2a_if_thrift=>c_type-bool_true OR element_type > zparq2a_if_thrift=>c_type-uuid.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Unknown element type { element_type }|.
    ELSEIF size < 0.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Negative list size { size }|.
    ENDIF.
    IF size < 15.
      writer->write_byte( size * 16 + element_type ).
    ELSE.
      writer->write_byte( 240 + element_type ).
      writer->write_varint( CONV #( size ) ).
    ENDIF.
  ENDMETHOD.

  METHOD write_union.
    write_struct_begin( ).
    IF value-member <> 0.
      write_field_begin( id = value-member type = zparq2a_if_thrift=>c_type-struct ).
      IF value-value IS INITIAL.
        writer->write_bytes( CONV #( zparq2a_if_thrift=>empty_struct ) ).
      ELSE.
        writer->write_bytes( value-value ).
      ENDIF.
    ENDIF.
    write_struct_end( ).
  ENDMETHOD.

  METHOD write_raw.
    writer->write_bytes( value ).
  ENDMETHOD.

  METHOD get_result.
    result = writer->get_result( ).
  ENDMETHOD.

  METHOD write_header.
    IF frames IS INITIAL.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Field { id } written outside a struct|.
    ELSEIF id <= 0 OR id > 32767.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Field id { id } is out of range|.
    ENDIF.
    DATA(frame) = REF #( frames[ lines( frames ) ] ).
    DATA(delta) = id - frame->last_id.
    IF delta > 0 AND delta <= 15.
      writer->write_byte( delta * 16 + type ).
    ELSE.
      writer->write_byte( type ).
      writer->write_zigzag_varint( CONV #( id ) ).
    ENDIF.
    frame->last_id = id.
  ENDMETHOD.

  METHOD flush_unknown.
    IF frames IS INITIAL.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Struct end without struct begin|.
    ENDIF.
    DATA(frame) = REF #( frames[ lines( frames ) ] ).
    WHILE frame->pending IS NOT INITIAL AND frame->pending[ 1 ]-id < below.
      DATA(field) = frame->pending[ 1 ].
      DELETE frame->pending INDEX 1.
      write_header( id = field-id type = field-type ).
      writer->write_bytes( field-value ).
    ENDWHILE.
  ENDMETHOD.

ENDCLASS.
