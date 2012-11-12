#if __STDC__
int parseLine(char *line, struct SquidInfo *s)
#else
int parseLine(line, s)
     char *line;
     struct SquidInfo *s;
#endif
{
  char *p, *d = NULL, *a = NULL, *e = NULL, *o, *field;
  int i = 0;
  char c;
  int report_once = 1;
  size_t strsz;
  int ndx = 0;
  
  field = strtok(line,"\t ");
  /*field holds each fetched url*/
  /* Let's first decode the url and then test it. Fixes bug2. */
  HTUnEscape(field);

  if(field == NULL)
    return 0;
  strcpy(s->orig,field);
  /* Now convert url to lowercase chars */ 
  for(p=field; *p != '\0'; p++) {
    *p = tolower(*p);
  }
  s->url[0] = s->protocol[0] = s->domain[0] = s->src[0] = s->ident[0] = 
    s->method[0] = s->srcDomain[0] = s->surl[0] =  '\0';
  s->dot = 0;
  s->port = 0;
  p = strstr(field,"://");
  /* sgLogError("Debug P2 = %s", p); */
  if(p == NULL) { /* no protocol, defaults to http */
    strcpy(s->protocol,"unknown");
    p = field;
  } else {
    strncpy(s->protocol,field,p - field);
    *(s->protocol + ( p - field)) = '\0';
    p+=3; /* JMC -- 3 == strlen("://") */
    /* Now p only holds the pure URI */
    /* Fix for multiple slash vulnerability (bug1). */
    /* Check if there are still two or more slashes in sequence which must not happen */
    strsz = strlen(p);

    /* loop thru the string 'p' until the char '?' is hit or the "end" is hit */
    while('?' != p[ndx] && '\0' != p[ndx])
    {
        /* in case this is a '://' skip over it, but try to not read past EOS */
        if(3 <= strsz-ndx) {
          if(':' == p[ndx] && '/' == p[ndx+1] && '/' == p[ndx+2]) {
           ndx+=3; /* 3 == strlen("://"); */
          }
        }
        
       /* if this char and the next char are slashes,
 *           then shift the rest of the string left one char */
       if('/' == p[ndx] && '/' == p[ndx+1]) {
         size_t sz = strlen(p+ndx+1);
         strncpy(p+ndx,p+ndx+1, sz);
         p[ndx+sz] = '\0';
          if(1 == report_once) {
             sgLogError("Warning: Possible bypass attempt. Found multiple slashes where only one is expected: %s", s->orig); 
            report_once--;
          }
      }
      else
      {
        /* increment the string indexer */
	assert(ndx < strlen(p));
        ndx++;
      }
    }
  }

  i=0;
  d = strchr(p,'/'); /* find domain end */
  /* Check for the single URIs (d) */
  /* sgLogError("URL: %s", d); */
  e = d;
  a = strchr(p,'@'); /* find auth  */
  if(a != NULL && ( a < d || d == NULL)) 
    p = a + 1;
  a = strchr(p,':'); /* find port */;
  if(a != NULL && (a < d || d == NULL)){
    o = a + strspn(a+1,"0123456789") + 1;
    c = *o;
    *o = '\0';
    s->port = atoi(a+1);
    *o = c;
    e = a;
  }
  o=p;
  strcpy(s->furl,p);
  if (p[0] == 'w' || p[0] == 'f' ) {
    if ((p[0] == 'w' && p[1] == 'w' && p[2] == 'w') ||
	(p[0] == 'w' && p[1] == 'e' && p[2] == 'b') ||
	(p[0] == 'f' && p[1] == 't' && p[2] == 'p')) {
      p+=3;
      while (p[0] >= '0' && p[0] <= '9')
	p++;
      if (p[0] != '.')
	p=o; /* not a hostname */
      else
	p++;
    }
  }
  if(e == NULL){
    strcpy(s->domain,o);
    strcpy(s->surl,p);
  }
  else {
    strncpy(s->domain,o,e - o);
    strcpy(s->surl,p);
    *(s->domain + (e - o)) = '\0';
    *(s->surl + (e - p)) = '\0';
  }
  //strcpy(s->surl,s->domain);
  if(strspn(s->domain,".0123456789") == strlen(s->domain))
    s->dot = 1;
  if(d != NULL)
    strcat(s->surl,d);
  s->strippedurl = s->surl;

  while((p = strtok(NULL," \t\n")) != NULL){
    switch(i){
    case 0: /* src */
      o = strchr(p,'/');
      if(o != NULL){
	strncpy(s->src,p,o-p);
	strcpy(s->srcDomain,o+1);
	s->src[o-p]='\0';
	if(*s->srcDomain == '-') {
	  s->srcDomain[0] = '\0';
	}
      } else {
	strcpy(s->src,p);
      }
      break;
    case 1: /* ident */
      if(strcmp(p,"-")){
	strcpy(s->ident,p);
	for(p=s->ident; *p != '\0'; p++) /* convert ident to lowercase chars */
	  *p = tolower(*p);
      } else
	s->ident[0] = '\0';
      break;
    case 2: /* method */
      strcpy(s->method,p);
      break;
    }
    i++;
  }
  if(s->domain[0] == '\0') {
/*    sgLogError("Debug: Domain is NULL: %s", s->orig); */
    return 0;
  }
  if(s->method[0] == '\0') {
/*    sgLogError("Debug: Method is NULL: %s", s->orig); */
    return 0;
  }
  return 1;
}
