#' Get metadata for objects in the Getty Museum.
#'
#' @export
#' @param id An object id
#' @param ascii (logical) Allow non-ascii characters. Set to \code{TRUE} to show
#' non-ascii characters. Default: FALSE
#' @param ... Curl args passed on to \code{\link[httr]{GET}}
#' @examples \dontrun{
#' getty(233750)
#' getty(329471)
#' getty(138860)
#' getty(8197)
#' getty(3242)
#' getty(4967)
#' getty(112297)
#' getty(253190)
#' lapply(c(140725,8197), getty)
#'
#' ## doesn't work, different url and html schema
#' ### see http://search.getty.edu/gri/records/griobject?objectid=301703057
#' # getty(id=301703057)
#' }
getty <- function(id, ascii = FALSE, ...){
  out <- getty_GET(gettybase(), list(objectid = id), ...)
  getty_parse(out, id, ascii)
}

getty_GET <- function(url, args = NULL, ...){
  res <- GET(url, query = args, ...)
  if (grepl("No Object Found", c2utf8(res))) stop(args$objectid, " not found", call. = FALSE)
  stop_for_status(res)
  c2utf8(res)
}

#' @export
print.getty <- function(x, ...){
  cat(sprintf("<Getty metadata> %s", x$name), sep = "\n")
  catpaswrap(x$artist, "Artist", "  ")
  cat("  Provenance", sep = "\n")
  for (i in seq_along(x$provenance)) {
    cat(sprintf("     %s: %s", x$provenance[[i]]$name, x$provenance[[i]]$value), sep = "\n")
  }
  cat("  Description:", sep = "\n")
  for (i in seq_along(x$description)) {
    cat(sprintf("     %s: %s", x$description[[i]]$name, x$description[[i]]$value), sep = "\n")
  }
  cat("  Exhibition history:", sep = "\n")
  for (i in seq_along(x$history)) {
    catpaswrap(x$history[[i]]$where_when, x$history[[i]]$text, "     ")
  }
}

l2i <- function(x) if (x) 1 else 0

getty_parse <- function(x, id, ascii){
  tmp <- htmlParse(x)
  name <- gsub("\n|\\s\\s", "", xpathSApply(tmp, '//div[@id="cs-results-a"]//h1', xmlValue))
  link <- paste0(gettybase(), id)
  desc <- plist(xpathSApply(tmp, '//table[@summary="search results data table"]')[[1]])
  artist <- desc[grep("Artist", vapply(desc, "[[", "", 'name'))][[1]]$value
  prov <-
    plist(xpathSApply(tmp, '//table[@summary="Provenance Table"]')[[1]])
  hist1 <- xpathSApply(tmp, '//div[@id="cs-tabs-history"]')[[1]]
  hist2 <- xpathSApply(hist1, "p")
  hist3 <- lapply(hist2, function(z){
    tmp <- xmlToList(z)
    list(text=xmlValue(z), href=gethref(tmp))
  })
  hist <- Map(function(x,y) c(x,where_when=y), hist3, xpathSApply(hist1, "ul/li", xmlValue))
  hist <- rapply(hist, function(x) gsub("[^\x20-\x7F]", " ", x), how = "list")

  all <- list(name=name, link=link, artist=artist, provenance=prov,
              description=desc, history=hist)
  structure(nonascii(all, ascii), class="getty")
}

gethref <- function(b){
  out <- tryCatch(b$em$a$.attrs[['href']], error=function(e) e)
  if(inherits(out, "simpleError")) NA else out
}

plist <- function(ob){
  trytable <- readHTMLTable(ob)
  if(is.null(trytable)){ NULL } else {
    tmp <- apply(trytable, 1, as.list)
    lapply(tmp, function(x){
      x[[1]] <- sub(":", "", x[[1]])
      stats::setNames(x, c('name','value'))
    })
  }
}

gettybase <- function() "http://www.getty.edu/art/collection/objects"
#"http://search.getty.edu/museum/records/musobject"
