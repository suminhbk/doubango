/*
* Copyright (C) 2009 Mamadou Diop.
*
* Contact: Mamadou Diop <diopmamadou(at)doubango.org>
*	
* This file is part of Open Source Doubango Framework.
*
* DOUBANGO is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*	
* DOUBANGO is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*	
* You should have received a copy of the GNU General Public License
* along with DOUBANGO.
*
*/

/**@file tsip_header_Via.c
 * @brief SIP Via/v header as per RFC 3261 subclause 20.42.
 *
 * @author Mamadou Diop <diopmamadou(at)doubango.org>
 *
 * @date Created: Sat Nov 8 16:54:58 2009 mdiop
 */
#include "tinysip/headers/tsip_header_Via.h"

#include "tsk_debug.h"
#include "tsk_memory.h"



/***********************************
*	Ragel state machine.
*/
%%{
	machine tsip_machine_parser_header_Via;

	# Includes
	include tsip_machine_utils "./ragel/tsip_machine_utils.rl";


	action tag{
		tag_start = p;
	}

	action parse_protocol_name{
		TSK_PARSER_SET_STRING(hdr_via->proto_name);
	}

	action parse_protocol_version{
		TSK_PARSER_SET_STRING(hdr_via->proto_version);
	}

	action parse_host{
		TSK_PARSER_SET_STRING(hdr_via->host);
		if(hdr_via->host && *hdr_via->host == '['){
			tsk_strunquote_2(&hdr_via->host, '[', ']');
		}
	}

	action parse_port{
		TSK_PARSER_SET_INTEGER(hdr_via->port);
	}

	action parse_transport{
		TSK_PARSER_SET_STRING(hdr_via->transport);
	}

	action parse_ttl{
		TSK_PARSER_SET_INTEGER(hdr_via->ttl);
	}

	action parse_maddr{
		TSK_PARSER_SET_STRING(hdr_via->maddr);
	}
	
	action parse_received{
		TSK_PARSER_SET_STRING(hdr_via->received);
	}

	action parse_branch{
		TSK_PARSER_SET_STRING(hdr_via->branch);
	}

	action parse_comp{
		TSK_PARSER_SET_STRING(hdr_via->comp);
	}

	action parse_rport{
		TSK_PARSER_SET_INTEGER(hdr_via->rport);
	}

	action has_rport{
		if(hdr_via->rport <0){
			hdr_via->rport = 0;
		}
	}

	action parse_param{
		TSK_PARSER_ADD_PARAM(TSIP_HEADER_PARAMS(hdr_via));
	}
	
	action eob{
		
	}

	protocol_name = "SIP"i | token >tag %parse_protocol_name;
	protocol_version = token >tag %parse_protocol_version;
	transport = ("UDP"i | "TCP"i | "TLS"i | "SCTP"i | "TLS-SCTP"i | other_transport) >tag %parse_transport;
	sent_protocol = protocol_name SLASH protocol_version SLASH transport;
	sent_by = host>tag %parse_host ( COLON port >tag %parse_port )?;
	via_ttl = "ttl"i EQUAL ttl >tag %parse_ttl;
	via_maddr = "maddr"i EQUAL host >tag %parse_maddr;
	via_received = "received"i EQUAL ( IPv4address | IPv6address )>tag %parse_received;
	via_branch = "branch"i EQUAL token >tag %parse_branch;
	via_compression = "comp"i EQUAL ( "sigcomp"i | other_compression )>tag %parse_comp;
	response_port = "rport"i ( EQUAL DIGIT+ >tag %parse_rport )? %has_rport;
	via_extension = (generic_param) >tag %parse_param;
	via_params = (via_ttl | via_maddr | via_received | via_branch | via_compression | response_port)@1 | (via_extension)@0;
	via_parm = sent_protocol LWS sent_by ( SEMI via_params )*;
	Via = ( "Via"i | "v"i ) HCOLON via_parm ( COMMA via_parm )*;
	
	# Entry point
	main := Via :>CRLF @eob;
}%%


tsip_header_Via_t* tsip_header_Via_create(const char* proto_name, const char* proto_version, const char* transport, const char* host, uint16_t port)
{
	return tsk_object_new(TSIP_HEADER_VIA_VA_ARGS(proto_name, proto_version, transport, host, port));
}
tsip_header_Via_t* tsip_header_Via_create_null()
{
	return tsip_header_Via_create(tsk_null, tsk_null, tsk_null, tsk_null, 0);
}

int tsip_header_Via_tostring(const tsip_header_t* header, tsk_buffer_t* output)
{
	if(header){
		const tsip_header_Via_t *Via = (const tsip_header_Via_t *)header;
		tsk_istr_t port, rport, ttl;
		int ipv6 = (Via->host && tsk_strcontains(Via->host, tsk_strlen(Via->host), ":"));

		if(Via->port){
			tsk_itoa(Via->port, &port);
		}
		if(Via->rport){
			tsk_itoa(Via->rport, &rport);
		}
		if(Via->ttl){
			tsk_itoa(Via->ttl, &ttl);
		}

		/* SIP/2.0/UDP [::]:1988;test=1234;comp=sigcomp;rport=254;ttl=457;received=192.0.2.101;branch=z9hG4bK1245420841406\r\n" */
		return tsk_buffer_append_2(output, "%s/%s/%s %s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s",

			Via->proto_name ? Via->proto_name : "SIP",

			Via->proto_version ? Via->proto_version : "2.0",

			Via->transport ? Via->transport : "UDP",

			ipv6 ? "[" : "",
			Via->host ? Via->host : "127.0.0.1",
			ipv6 ? "]" : "",

			Via->port ? ":" : "",
			Via->port ? port : "",

			Via->maddr ? ";maddr=" : "",
			Via->maddr ? Via->maddr : "",

			Via->sigcomp_id ? ";sigcomp-id=" : "",
			Via->sigcomp_id ? Via->sigcomp_id : "",

			Via->comp ? ";comp=" : "",
			Via->comp ? Via->comp : "",

			Via->rport>=0 ? (Via->rport>0?";rport=":";rport") : "",
			Via->rport>0 ? rport : "",

			Via->ttl>=0 ? (Via->ttl>0?";rport=":";rport") : "",
			Via->ttl>0 ? ttl : "",

			Via->received ? ";received=" : "",
			Via->received ? Via->received : "",

			Via->branch ? ";branch=" : "",
			Via->branch ? Via->branch : ""
			);
	}
	return -1;
}

tsip_header_Via_t *tsip_header_Via_parse(const char *data, size_t size)
{
	int cs = 0;
	const char *p = data;
	const char *pe = p + size;
	const char *eof = pe;
	tsip_header_Via_t *hdr_via = tsip_header_Via_create_null();
	
	const char *tag_start;

	%%write data;
	%%write init;
	%%write exec;
	
	if( cs < %%{ write first_final; }%% ){
		TSK_DEBUG_ERROR("Failed to parse 'Via' header.");
		TSK_OBJECT_SAFE_FREE(hdr_via);
	}
	
	return hdr_via;
}











//========================================================
//	Via header object definition
//

static tsk_object_t* tsip_header_Via_ctor(tsk_object_t *self, va_list * app)
{
	tsip_header_Via_t *via = self;
	if(via){
		const char* proto_name = va_arg(*app, const char *);
		const char* proto_version = va_arg(*app, const char *);
		const char* transport = va_arg(*app, const char *);
		const char* host = va_arg(*app, const char *);
#if defined(__GNUC__)
		uint16_t port = (uint16_t)va_arg(*app, unsigned);
#else
		uint16_t port = va_arg(*app, uint16_t);
#endif

		if(proto_name) via->proto_name = tsk_strdup(proto_name);
		if(proto_version) via->proto_version = tsk_strdup(proto_version);
		if(transport) via->transport = tsk_strdup(transport);
		if(host) via->host = tsk_strdup(host);
		via->port = port;

		via->rport = -1;
		via->ttl = -1;
		
		TSIP_HEADER(via)->type = tsip_htype_Via;
		TSIP_HEADER(via)->tostring = tsip_header_Via_tostring;
	}
	else{
		TSK_DEBUG_ERROR("Failed to create new Via header.");
	}
	return self;
}

static tsk_object_t* tsip_header_Via_dtor(tsk_object_t *self)
{
	tsip_header_Via_t *via = self;
	if(via){
		TSK_FREE(via->branch);
		TSK_FREE(via->comp);
		TSK_FREE(via->host);
		TSK_FREE(via->maddr);
		TSK_FREE(via->proto_name);
		TSK_FREE(via->proto_version);
		TSK_FREE(via->received);
		TSK_FREE(via->sigcomp_id);
		TSK_FREE(via->transport);
		TSK_OBJECT_SAFE_FREE(TSIP_HEADER_PARAMS(via));
	}
	else{
		TSK_DEBUG_ERROR("Null Via header.");
	}

	return self;
}

static const tsk_object_def_t tsip_header_Via_def_s = 
{
	sizeof(tsip_header_Via_t),
	tsip_header_Via_ctor,
	tsip_header_Via_dtor,
	tsk_null
};
const tsk_object_def_t *tsip_header_Via_def_t = &tsip_header_Via_def_s;