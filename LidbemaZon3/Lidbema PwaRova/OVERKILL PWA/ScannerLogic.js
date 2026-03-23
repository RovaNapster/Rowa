// ============================================================================
// LIDBEMA PWA: CORE SCANNER LOOP (v4.0)
// ============================================================================

async function processAiScan(scanResult, userLevel) {
    const confidence = scanResult.ai_score; // T.ex. 99.8
    const partId = scanResult.article_id;   // T.ex. 'HIFI_SO_11092'

    // 1. EXPRESS-LÄGE (Lvl 1 & Hög säkerhet)
    if (userLevel === 'LVL_1' && confidence >= 99.5) {
        
        // Fysisk feedback: Två korta, snabba vibrationer ("Klick-klick")
        if (navigator.vibrate) navigator.vibrate([50, 50, 50]); 
        
        // Visuell feedback: Skärmen blinkar grönt i 0.3 sekunder
        ui.flashScreen('var(--nexus-green)', 300);
        
        // Databas-anrop
        await LidbemaAPI.checkoutItem(partId);
        ui.showToast(`✅ ${partId} utcheckad!`);
    } 
    
    // 2. MÄSTARE-LOOP (Praktikant eller Låg säkerhet)
    else {
        
        // Fysisk feedback: Ett långt, tungt surr ("Fel/Vänta")
        if (navigator.vibrate) navigator.vibrate(600);
        
        // Visuell feedback: Skärmen låser sig i gult
        ui.setScreenState('var(--nexus-yellow)');
        
        // Kallar på överordnad
        await LidbemaAPI.requestVerification(partId);
        ui.showModal('⚠️ VÄNTAR PÅ GODKÄNNANDE');
    }
}