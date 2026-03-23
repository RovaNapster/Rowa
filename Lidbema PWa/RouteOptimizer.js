// ============================================================================
// CORE: DYNAMIC BATCH ROUTING
// ============================================================================

export function generateMagicRoute(orderItems) {
    console.log("⚡ [MAGI] Optimerar plockrutt för Zon 3...");

    // Sortera artiklarna baserat på hyllans ID (t.ex. 'A0112' före 'B0210')
    const optimizedList = orderItems.sort((a, b) => {
        // Enkel alfanumerisk jämförelse av hyll-strängarna
        if (a.shelfLocation < b.shelfLocation) return -1;
        if (a.shelfLocation > b.shelfLocation) return 1;
        return 0;
    });

    // Gruppera ihop artiklar som ligger på exakt samma hylla
    const groupedRoute = optimizedList.reduce((acc, item) => {
        if (!acc[item.shelfLocation]) acc[item.shelfLocation] = [];
        acc[item.shelfLocation].push(item);
        return acc;
    }, {});

    return groupedRoute;
    // PWA:n ritar nu upp: "Stanna vid Hylla A0112 och plocka både Filter och Olja"
}