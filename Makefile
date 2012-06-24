#!/usr/bin/env pmake -f

# use make Q= to enable the debug mode.
Q ?= @

# directories
TMPLDIR  = ./template
STYLEDIR = ./style
BINDIR   = ./bin
LANGDIR  = ./lang
SRCDIR   = ./src
DESTDIR  = ./pub
DBDIR    = ./db
TMPDIR   = ./tmp

# template's files
header  ?= ${TMPLDIR}/header.xhtml
footer  ?= ${TMPLDIR}/footer.xhtml
element ?= ${TMPLDIR}/element.xhtml
article ?= ${TMPLDIR}/article.xhtml

# programs
markdown ?= markdown
lua      ?= lua
parser   ?= ${BINDIR}/parser.lua
echo     ?= echo
cat      ?= cat

# include some VARIABLES
# first main variables
.include "makefly.rc"
# then translation variables
.include "${LANGDIR}/translate.${BLOG_LANG}"

# some files'list
FILES != cd ${SRCDIR}; ls
DBFILES != cd ${DBDIR}; ls|sort -r|sort -r
MAINDBFILES != cd ${DBDIR}; ls|sort -r|head -n ${MAX_POST}

# BEGIN
all: ${FILES:S/.md/.xhtml/g:S/^/${DESTDIR}\//} ${DESTDIR}/simple.css ${DESTDIR}/index.xhtml ${DESTDIR}/rss.xml ${DESTDIR}/list.xhtml

# Create target post file LIST
# EXAMPLE: pub/article1.xhtml
.for FILE in ${FILES}
TARGET_${FILE} = ${FILE:S/.md$/.xhtml/:S/^/${DESTDIR}\//}
.endfor

# Create temporary files LIST (this temporary files will fetch some infos for Post List and Homepage)
# EXAMPLE: tmp/130435,article1.mk
.for FILE in ${DBFILES}
TMP_${FILE} = ${FILE:S/^/${TMPDIR}\//}
.endfor

# Do each FINAL post file
# EXAMPLE: pub/article1.xhtml
.for FILE in ${FILES}
${TARGET_${FILE}}: ${SRCDIR}/${FILE}
	$Q{ \
		{ \
			cat ${header} | ${lua} ${parser} "BLOG_TITLE=${BLOG_TITLE}" "BASE_URL=${BASE_URL}" "HOME_TITLE=${HOME_TITLE}" "POST_LIST_TITLE=${POST_LIST_TITLE}" "LANG=${BLOG_LANG}"      && \
			echo "      <article>"                                       && \
			${markdown} ${SRCDIR}/${FILE} |sed "s|^|        |g"          && \
			echo "      </article>"                                      && \
			cat ${footer} | ${lua} ${parser} "POWERED_BY=${POWERED_BY}"  ; \
		} > ${TARGET_${FILE}} || { \
			rm -f ${TARGET_${FILE}}                           ; \
			echo "-- Error while building ${TARGET_${FILE}}." ; \
			false                                             ; \
		} ; \
	} && echo "-- Page built: ${TARGET_${FILE}}."
.endfor

# Do each TMP post files
# EXAMPLE: tmp/130435,article1.mk AND tmp/130435,article1.mk.list AND tmp/130435,article1.mk.rss
.for FILE in ${DBFILES}
.include "${DBDIR}/${FILE}"
TITLE_${FILE} != echo ${TITLE}
TMSTMP_${FILE} != echo ${FILE}| cut -d ',' -f 1
POSTDATE_${FILE} != date -d "@${TMSTMP_${FILE}}" +'%Y-%m-%d %H:%M:%S'
NAME_${FILE} != echo ${FILE}| sed -e 's|.mk$$|.xhtml|' -e 's|^.*,||'
DESC_${FILE} != echo ${DESCRIPTION}
CONTENT_${FILE} != ${markdown} ${SRCDIR}/${NAME_${FILE}:S/.xhtml$/.md/}
${TMP_${FILE}}: ${TARGET_${NAME_${FILE}}}
# Template for Post List page
	$Qcat ${element} | ${lua} ${parser} "TITLE=${TITLE_${FILE}}" "DATE=${POSTDATE_${FILE}}" "FILE=${NAME_${FILE}}" > ${TMPDIR}/${FILE}.list
# Template for Home page
	$Qcat ${article} | ${lua} ${parser} "CONTENT=${CONTENT_${FILE}}" "TITLE=${TITLE_${FILE}}" "FILE=${NAME_${FILE}}" "DATE=${POSTDATE_${FILE}}" "PERMALINK_TITLE=${PERMALINK_TITLE}"> ${TMPDIR}/${FILE}
# Add article's title to page's header
	$Qcat ${DESTDIR}/${NAME_${FILE}} | ${lua} ${parser} "TITLE=${TITLE_${FILE}}" "RSS_FEED_NAME=${RSS_FEED_NAME}"  > ${TMPDIR}/${NAME_${FILE}}
# Move temporary file to pub
	$Qmv ${TMPDIR}/${NAME_${FILE}} ${DESTDIR}/${NAME_${FILE}}
# Template for RSS Feed
	$Qcat ${TMPLDIR}/feed.element.rss | ${lua} ${parser} "TITLE=${TITLE_${FILE}}" "DESCRIPTION=${DESC_${FILE}}" "LINK=${BASE_URL}/${NAME_${FILE}}" > ${TMPDIR}/${FILE}.rss
.endfor

# Do CSS file
${DESTDIR}/simple.css: ${STYLEDIR}/simple.css
	$Q{ \
		cp ${STYLEDIR}/simple.css ${DESTDIR}/simple.css ; \
	} && echo "-- CSS: ${DESTDIR}/simple.css."

# Do Homepage
# EXAMPLE: pub/index.xhtml
${DESTDIR}/index.xhtml: ${DBFILES:S/^/${TMPDIR}\//}
	$Q{ \
		cat ${header} >> ${TMPDIR}/index.xhtml ; \
		cat ${MAINDBFILES:S/^/${TMPDIR}\//} >> ${TMPDIR}/index.xhtml ; \
		rm -f ${DBFILES:S/^/${TMPDIR}\//} ; \
		cat ${footer} >> ${TMPDIR}/index.xhtml ; \
		cat ${TMPDIR}/index.xhtml |${lua} ${parser} "BASE_URL=${BASE_URL}" "BLOG_TITLE=${BLOG_TITLE}" "TITLE=${HOME_TITLE}" "RSS_FEED_NAME=${RSS_FEED_NAME}" "HOME_TITLE=${HOME_TITLE}" "POST_LIST_TITLE=${POST_LIST_TITLE}" "LANG=${BLOG_LANG}" "POWERED_BY=${POWERED_BY}" > ${TMPDIR}/index.xhtml.tmp; \
		mv ${TMPDIR}/index.xhtml.tmp ${DESTDIR}/index.xhtml ; \
		rm ${TMPDIR}/index.xhtml ; \
	}

# Do RSS Feed
# EXAMPLE: pub/rss.xml
${DESTDIR}/rss.xml: ${DBFILES:S/^/${TMPDIR}\//}
	$Q{ \
		cat ${TMPLDIR}/feed.header.rss | ${lua} ${parser} "BLOG_TITLE=${BLOG_TITLE}" "BLOG_DESCRIPTION=${BLOG_DESCRIPTION}" "BASE_URL=${BASE_URL}" > ${DESTDIR}/rss.xml ; \
		cat ${DBFILES:S/^/${TMPDIR}\//:S/$/.rss/} >> ${DESTDIR}/rss.xml ; \
		rm -f ${DBFILES:S/^/${TMPDIR}\//:S/$/.rss/} ; \
		cat ${TMPLDIR}/feed.footer.rss >> ${DESTDIR}/rss.xml ; \
	}

# Do Post List page
# EXAMPLE: pub/list.xhtml
${DESTDIR}/list.xhtml: ${DBFILES:S/^/${TMPDIR}\//}
	$Q{ \
		cat ${header} >> ${TMPDIR}/list.xhtml ; \
		cat ${DBFILES:S/^/${TMPDIR}\//:S/$/.list/} >> ${TMPDIR}/list.xhtml ; \
		rm -f ${DBFILES:S/^/${TMPDIR}\//:S/$/.list/} ; \
		cat ${footer} >> ${TMPDIR}/list.xhtml ; \
		cat ${TMPDIR}/list.xhtml | ${lua} ${parser} "BLOG_TITLE=${BLOG_TITLE}" "BLOG_DESCRIPTION=${BLOG_DESCRIPTION}" "BASE_URL=${BASE_URL}" "RSS_FEED_NAME=${RSS_FEED_NAME}" "HOME_TITLE=${HOME_TITLE}" "POST_LIST_TITLE=${POST_LIST_TITLE}" "TITLE=${POST_LIST_TITLE}" "LANG=${BLOG_LANG}" "POWERED_BY=${POWERED_BY}" > ${DESTDIR}/list.xhtml ; \
    rm ${TMPDIR}/list.xhtml ; \
	}

# Clean all directories
# EXAMPLE: pub/* AND tmp/*
clean: ${FILES:S/.md$/.xhtml/:S/^/${DESTDIR}\//} ${DESTDIR}/simple.css ${DESTDIR}/index.xhtml ${DESTDIR}/rss.xml ${DESTDIR}/list.xhtml
	$Q{ \
		rm -f ${DESTDIR}/* ; \
		rm -f ${TMPDIR}/* ; \
	}

# END
.MAIN: all

#vim :tabstop=2:softtabstop=2:shiftwidth=2:noexpandtab
