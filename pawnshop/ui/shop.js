window.addEventListener('message', function(event) {
    const data = event.data;
    if (data.action === 'openMenu') {
        refreshData();
    }
});

function openTab(tabName) {
    document.querySelectorAll('.tab-button').forEach(button => button.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
    document.querySelector(`.tab-button[onclick="openTab('${tabName}')"]`).classList.add('active');
    document.getElementById(tabName).classList.add('active');
}

function refreshData() {
    fetch('http://pawnshop/getCompanyData').then(response => response.json()).then(data => {
        document.getElementById('completedMissions').textContent = data.completedMissions;
        document.getElementById('acceptedMissions').textContent = data.acceptedMissions;
        document.getElementById('employeeCount').textContent = data.employeeCount;
        document.getElementById('level').textContent = data.level;
        document.getElementById('exp').textContent = data.exp;
        document.getElementById('nextExp').textContent = Config.LevelExp[data.level] || 5000;
        document.getElementById('earnings').textContent = data.earnings;
        document.getElementById('balance').textContent = `Saldo: $${data.balance}`;
    });

    fetch('http://pawnshop/getAvailableMissions').then(response => response.json()).then(missions => {
        const container = document.getElementById('availableMissions');
        container.innerHTML = '';
        if (missions.error) {
            container.innerHTML = `<p>${missions.error}</p>`;
        } else {
            missions.forEach(mission => {
                const div = document.createElement('div');
                div.className = 'mission-item';
                div.innerHTML = `
                    <h3>${mission.name}</h3>
                    <p>${mission.description}</p>
                    <p>Wymagane przedmioty: ${mission.requiredItems.map(i => `${QBCore.Shared.Items[i.name].label}: ${i.amount}`).join(', ')}</p>
                    <p>Nagroda: $<span style="color: ${mission.reward < 5000 ? '#2cb67d' : '#800080'}">${mission.reward}</span></p>
                    <button onclick="acceptMission(${mission.id})">Przyjmij</button>
                `;
                container.appendChild(div);
            });
        }
    });

    fetch('http://pawnshop/getActiveMissions').then(response => response.json()).then(missions => {
        const container = document.getElementById('activeMissions');
        container.innerHTML = '';
        missions.forEach(mission => {
            const distance = getDistance(mission.location.coords);
            const div = document.createElement('div');
            div.className = 'mission-item';
            div.innerHTML = `
                <h3>${mission.name}</h3>
                <p>Lokalizacja: ${distance.toFixed(1)}m</p>
                <p>Wymagane przedmioty: ${mission.requiredItems.map(i => `${QBCore.Shared.Items[i.name].label}: ${i.amount}`).join(', ')}</p>
                <p>Status: ${mission.status}</p>
                <p>Nagroda: $<span style="color: ${mission.reward < 5000 ? '#2cb67d' : '#800080'}">${mission.reward}</span></p>
            `;
            container.appendChild(div);
        });
    });

    fetch('http://pawnshop/getHistory').then(response => response.json()).then(history => {
        const container = document.getElementById('missionHistory');
        container.innerHTML = '';
        history.forEach(mission => {
            const div = document.createElement('div');
            div.className = 'history-item';
            div.innerHTML = `
                <p>Misja: ${Config.Missions[mission.mission_id].name}</p>
                <p>Nagroda: $${mission.reward}</p>
                <p>Zakończono: ${new Date(mission.completed_at).toLocaleString()}</p>
            `;
            container.appendChild(div);
        });
    });

    fetch('http://pawnshop/getShopItems').then(response => response.json()).then(items => {
        const container = document.getElementById('shopItems');
        container.innerHTML = '';
        items.forEach(item => {
            const div = document.createElement('div');
            div.className = 'shop-item';
            div.innerHTML = `
                <h3>${QBCore.Shared.Items[item.item_name].label} (x${item.amount})</h3>
                <p>Cena: $<span style="color: ${item.price < 5000 ? '#2cb67d' : '#800080'}">${item.price}</span></p>
                <p>Opis: ${item.description}</p>
                <p>Wystawił: ${item.citizenid}</p>
                ${item.citizenid === QBCore.Functions.GetPlayerData().citizenid ? '<button onclick="removeItem(' + item.id + ')">Usuń</button>' : ''}
            `;
            container.appendChild(div);
        });
    });
}

function acceptMission(missionId) {
    fetch('http://pawnshop/acceptMission', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ missionId: missionId })
    }).then(response => response.json()).then(data => {
        if (data.status === 'ok') refreshData();
    });
}

function listItem() {
    const itemName = document.getElementById('itemName').value;
    const itemPrice = parseInt(document.getElementById('itemPrice').value);
    const itemDescription = document.getElementById('itemDescription').value;
    fetch('http://pawnshop/listItem', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ itemName, price: itemPrice, description: itemDescription })
    }).then(response => response.json()).then(data => {
        if (data.status === 'ok') {
            document.getElementById('itemName').value = '';
            document.getElementById('itemPrice').value = '';
            document.getElementById('itemDescription').value = '';
            refreshData();
        }
    });
}

function removeItem(itemId) {
    fetch('http://pawnshop/removeItem', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ itemId })
    }).then(response => response.json()).then(data => {
        if (data.status === 'ok') refreshData();
    });
}

function getDistance(coords) {
    const playerCoords = GetEntityCoords(PlayerPedId());
    function getDistanceBetweenCoords(playerCoords, coords) {
    return new Vector3(playerCoords.x, playerCoords.y, playerCoords.z)
        .distance(new Vector3(coords.x, coords.y, coords.z));
}

}

function closeMenu() {
    fetch('http://pawnshop/closeMenu', { method: 'POST' }).then(() => {
        SetNuiFocus(false, false);
    });
}