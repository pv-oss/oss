
#if __STDC__
int main(int    argc,
         char   **argv,
	 char   **envp)
#else
int main(argc, argv, envp)
     int argc;
     char *argv[];
     char *envp[];
#endif
{
  struct SquidInfo squidInfo;
  char buf[MAX_BUF];
  char *redirect,tmp[MAX_BUF];
  tmp[MAX_BUF-1] = '\0';
  while(1) {
    while(fgets(buf, MAX_BUF, stdin) != NULL){
      if(sig_hup) {
	sgReloadConfig();
      }
      if(failsafe_mode) {
	puts("");
	fflush(stdout);
	if(sig_hup){
          sgReloadConfig();
	}
	continue;
      }
      if(parseLine(buf,&squidInfo) != 1){
	sgLogError("Error parsing squid line: %s",buf);
	puts("");
      }
        else {
	src = Source;
	for(;;){
	  strncpy(tmp,squidInfo.src,MAX_BUF-1);
          tmp[MAX_BUF-1] = 0;   /* force null termination */
	  globalLogFile = NULL;
	  src = sgFindSource(src, tmp,squidInfo.ident,squidInfo.srcDomain);
	  acl = sgAclCheckSource(src);
	  if((redirect = sgAclAccess(src,acl,&squidInfo)) == NULL){
	    if(src == NULL || src->cont_search == 0){
	      puts(""); 
	      break;
	    } else
	      if(src->next != NULL){
		src = src->next;
		continue;
	      } else {
		puts("");
		break;
	      }
	  } else {
	    if(squidInfo.srcDomain[0] == '\0'){
	      squidInfo.srcDomain[0] = '-';
	      squidInfo.srcDomain[1] = '\0';
	    }
	    if(squidInfo.ident[0] == '\0'){
	      squidInfo.ident[0] = '-';
	      squidInfo.ident[1] = '\0';
	    }
	    fprintf(stdout,"%s %s/%s %s %s\n",redirect,squidInfo.src,
		    squidInfo.srcDomain,squidInfo.ident,
		    squidInfo.method);
            /* sgLogError("%s %s/%s %s %s\n",redirect,squidInfo.src,squidInfo.srcDomain,squidInfo.ident,squidInfo.method);  */
	    break;
	  }
	} /*for(;;)*/
      }
      fflush(stdout);
      if(sig_hup)
        sgReloadConfig();
    }
#if !HAVE_SIGACTION
#if HAVE_SIGNAL
    if(errno != EINTR){
      gettimeofday(&stop_time, NULL);
      stop_time.tv_sec = stop_time.tv_sec + globalDebugTimeDelta;
      sgLogError("squidGuard stopped (%d.%03d)",stop_time.tv_sec,stop_time.tv_usec/1000);
      exit(2);
    }
#endif
#else 
    gettimeofday(&stop_time, NULL);
    stop_time.tv_sec = stop_time.tv_sec + globalDebugTimeDelta;
    sgLogError("squidGuard stopped (%d.%03d)",stop_time.tv_sec,stop_time.tv_usec/1000);
    exit(0);
#endif
  }
  exit(0);
}
