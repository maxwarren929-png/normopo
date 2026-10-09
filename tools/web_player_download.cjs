'use strict';

// Retry both response acquisition and body reads. A 200 header is not proof
// that Chrome received the whole body. Progress must be rolled back on retry.
async function downloadPlayerAsset(url, consume, rollback) {
 for(let attempt=0;attempt<3;attempt++) {
  try {
   const response=await fetch(url);
   if(!response.ok)throw new Error('HTTP '+response.status);
   return await consume(response);
  } catch(error) {
   if(error?.name==='AbortError'||error?.cliDownloadFinal)throw error;
   rollback();
   if(attempt<2) {
    await new Promise(resolve=>setTimeout(resolve,500*(attempt+1)));
    continue;
   }
   const filename=new URL(url,location.href).pathname.split('/').pop();
   const failure=new Error('Could not download '+filename+' after 3 attempts: '+error.message);
   failure.cliDownloadFinal=true;
   window.dispatchEvent(new CustomEvent('cli-download-error',{detail:failure.message}));
   throw failure;
  }
 }
}
module.exports={downloadPlayerAsset};
