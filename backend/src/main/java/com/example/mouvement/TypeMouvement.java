package com.example.mouvement;



//TRANSFERT = déplacer du stock d'un LIEU vers un autre LIEU
//		→ il faut une source ET une destination
//         → donc il faut... des LIEUX (multi-emplacement) !

public enum TypeMouvement {
	ENTREE,      // ✅ mono : quantiteStock += quantite
	SORTIE,      // ✅ mono : quantiteStock -= quantite
	AJUSTEMENT,  // ✅ mono : correction d'inventaire
	TRANSFERT    // 🔮 activé QUAND on ajoutera les lieux (multi). Source→destination
}

