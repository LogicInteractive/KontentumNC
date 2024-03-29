#ifndef HXCPP_CONFIG_INCLUDED
#define HXCPP_CONFIG_INCLUDED

#if !defined(HX_LINUX) && !defined(NO_HX_LINUX)
#define HX_LINUX 
#endif

#if !defined(RASPBERRYPI) && !defined(NO_RASPBERRYPI)
#define RASPBERRYPI RASPBERRYPI
#endif

#if !defined(HXCPP_VISIT_ALLOCS) && !defined(NO_HXCPP_VISIT_ALLOCS)
#define HXCPP_VISIT_ALLOCS 
#endif

#if !defined(HXCPP_CHECK_POINTER) && !defined(NO_HXCPP_CHECK_POINTER)
#define HXCPP_CHECK_POINTER 
#endif

#if !defined(HXCPP_STACK_TRACE) && !defined(NO_HXCPP_STACK_TRACE)
#define HXCPP_STACK_TRACE 
#endif

#if !defined(HXCPP_STACK_LINE) && !defined(NO_HXCPP_STACK_LINE)
#define HXCPP_STACK_LINE 
#endif

#if !defined(HX_SMART_STRINGS) && !defined(NO_HX_SMART_STRINGS)
#define HX_SMART_STRINGS 
#endif

#if !defined(HXCPP_API_LEVEL) && !defined(NO_HXCPP_API_LEVEL)
#define HXCPP_API_LEVEL 400
#endif

#include <hxcpp.h>

#endif
