'use client'

import { useEffect, useState } from 'react'

type InstallPromptEvent = Event & {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed'; platform: string }>
}

export default function InstallPage(){
  const [deferredPrompt,setDeferredPrompt]=useState<InstallPromptEvent|null>(null)
  const [isIOS,setIsIOS]=useState(false)
  const [isAndroid,setIsAndroid]=useState(false)
  const [isStandalone,setIsStandalone]=useState(false)
  const [message,setMessage]=useState('')

  useEffect(()=>{
    const ua=navigator.userAgent||''
    const ios=/iPad|iPhone|iPod/.test(ua) || (navigator.platform==='MacIntel' && navigator.maxTouchPoints>1)
    const android=/Android/i.test(ua)
    const standalone=window.matchMedia('(display-mode: standalone)').matches || (navigator as any).standalone===true
    setIsIOS(ios);setIsAndroid(android);setIsStandalone(standalone)

    const handler=(e:Event)=>{
      e.preventDefault()
      setDeferredPrompt(e as InstallPromptEvent)
    }
    window.addEventListener('beforeinstallprompt',handler)
    return()=>window.removeEventListener('beforeinstallprompt',handler)
  },[])

  async function installAndroid(){
    if(isStandalone){
      window.location.href='/'
      return
    }
    if(deferredPrompt){
      await deferredPrompt.prompt()
      const choice=await deferredPrompt.userChoice
      if(choice.outcome==='accepted')setMessage('RYM_VARGANI installation started.')
      else setMessage('Installation was cancelled. You can install it anytime from the browser menu.')
      setDeferredPrompt(null)
      return
    }
    setMessage('Chrome मध्ये वरच्या ⋮ मेनूमधून “Install app” किंवा “Add to Home screen” निवडा.')
  }

  return <main className="installPage">
    <section className="installHero">
      <img src="/rym-logo.jpg" className="installLogo" alt="Rajasthan Yuvak Mandal"/>
      <div>
        <small>राजस्थान युवक मंडळ, संगमनेर</small>
        <h1>RYM_VARGANI</h1>
        <p>मोबाईलवर App म्हणून Install करा आणि वर्गणी संकलन अधिक सोप्या पद्धतीने करा.</p>
      </div>
    </section>

    {isStandalone?<section className="installCard successCard">
      <h2>✅ RYM_VARGANI आधीच Install आहे</h2>
      <p>App तुमच्या मोबाईलवर Home Screen वरून वापरता येईल.</p>
      <button className="installPrimary" onClick={()=>window.location.href='/'}>Open RYM_VARGANI</button>
    </section>:<>
      <section className={`installCard ${isAndroid?'activePlatform':''}`}>
        <div className="platformHead"><span className="platformIcon">🤖</span><div><h2>Android</h2><p>Chrome वापरा</p></div></div>
        <ol>
          <li>ही लिंक <b>Google Chrome</b> मध्ये उघडा.</li>
          <li>खालील <b>Install RYM_VARGANI</b> बटण दाबा.</li>
          <li>Install popup आल्यावर <b>Install</b> निवडा.</li>
          <li>App चे icon Home Screen वर दिसेल.</li>
        </ol>
        <button className="installPrimary" onClick={installAndroid}>Install RYM_VARGANI</button>
        {!deferredPrompt&&<small className="installHint">Install popup दिसला नाही तर Chrome → ⋮ → <b>Install app / Add to Home screen</b>.</small>}
      </section>

      <section className={`installCard ${isIOS?'activePlatform':''}`}>
        <div className="platformHead"><span className="platformIcon"></span><div><h2>iPhone / iPad</h2><p>Safari वापरा</p></div></div>
        <ol>
          <li>ही लिंक <b>Safari</b> मध्ये उघडा.</li>
          <li>खालील <b>Share</b> बटण <span className="shareSymbol">⬆</span> दाबा.</li>
          <li>खाली स्क्रोल करून <b>Add to Home Screen</b> निवडा.</li>
          <li>वरच्या बाजूला <b>Add</b> दाबा.</li>
          <li>RYM_VARGANI icon Home Screen वर दिसेल.</li>
        </ol>
        <div className="iosTip">iPhone वर वेबसाइटमधून Install popup देता येत नाही; Apple च्या नियमांनुसार Safari मधील <b>Add to Home Screen</b> वापरावे लागते.</div>
      </section>
    </>}

    {message&&<div className="installMessage">{message}</div>}

    <section className="installCard compactInstallCard">
      <h3>App Install न करता वापरायचे आहे?</h3>
      <button className="installSecondary" onClick={()=>window.location.href='/'}>Open RYM_VARGANI</button>
    </section>

    <footer className="installFooter">RYM_VARGANI · डिजिटल वर्गणी व्यवस्थापन प्रणाली</footer>
  </main>
}
